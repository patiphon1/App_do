import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/chat_service.dart';
import '../../widgets/rate_post_dialog.dart';
import '../../widgets/post_reviews_sheet.dart';

class ChatP2PPage extends StatefulWidget {
  const ChatP2PPage({
    super.key,
    required this.peerId,
    required this.kind,
    required this.postId,
    required this.postTitle,
    required this.chatId,
  });

  final String peerId;
  final String kind;
  final String postId;
  final String postTitle;
  final String chatId;

  @override
  State<ChatP2PPage> createState() => _ChatP2PPageState();
}

class _ChatP2PPageState extends State<ChatP2PPage> {
  final _msg = TextEditingController();
  final _listCtrl = ScrollController();
  bool _uploading = false;

  String? _postOwnerId; // ⬅️ เจ้าของโพสต์ที่แท้จริง (จาก posts/{postId}.userId)

  @override
  void initState() {
    super.initState();

    // สร้าง/รับรองแชท
    ChatService.instance.ensureChat(
      peerId: widget.peerId,
      kind: widget.kind,
      postId: widget.postId,
      postTitle: widget.postTitle,
    );

    // ⬅️ ต้องโหลดเจ้าของโพสต์ "ภายใน" initState (เมื่อเปิดหน้ามา)
    FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get()
        .then((doc) {
      if (!mounted) return;
      if (doc.exists) {
        setState(() => _postOwnerId = doc.data()?['userId'] as String?);
      }
    });
  }

  String _kindTh(String k) => switch (k) {
        'donate' => 'บริจาค',
        'request' => 'ขอรับ',
        'swap' => 'แลกเปลี่ยน',
        _ => k
      };

  Widget _postBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFFF4F6F8),
        child: Row(
          children: [
            const Icon(Icons.link, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'คุยจากโพสต์: ${widget.postTitle}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Future<void> _send() async {
    final txt = _msg.text.trim();
    if (txt.isEmpty) return;
    _msg.clear();

    await ChatService.instance.sendMessage(
      peerId: widget.peerId,
      text: txt,
      kind: widget.kind,
      postId: widget.postId,
      postTitle: widget.postTitle,
    );

    await Future.delayed(const Duration(milliseconds: 50));
    if (_listCtrl.hasClients) {
      _listCtrl.animateTo(
        _listCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_uploading) return;
    try {
      setState(() => _uploading = true);
      final file = await ChatService.instance.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      await ChatService.instance.sendImageMessage(
        peerId: widget.peerId,
        kind: widget.kind,
        imageFile: file,
        postId: widget.postId,
        postTitle: widget.postTitle,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // เปิดรีวิวของโพสต์นี้
  void _openPostReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PostReviewsSheet(
        postId: widget.postId,
        postTitle: widget.postTitle,
      ),
    );
  }

  Future<void> _endChatDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        double rating = 3;
        return AlertDialog(
          title: const Text('ให้คะแนนเจ้าของโพสต์'),
          content: StatefulBuilder(
            builder: (_, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('คุณต้องการให้กี่ดาว? (${_kindTh(widget.kind)})'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      icon: Icon(
                        i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setState(() => rating = i + 1),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
            ElevatedButton(
              child: const Text('ยืนยัน'),
              onPressed: () async {
                final myId = FirebaseAuth.instance.currentUser!.uid;
                if (myId == widget.peerId) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ห้ามให้คะแนนตัวเอง')),
                    );
                  }
                  return;
                }

                await ChatService.instance.ratePostOnce(
                  postId: widget.postId,
                  value: rating,
                );

                await ChatService.instance.sendSystemMessage(
                  peerId: widget.peerId,
                  kind: widget.kind,
                  text: 'จบการ${_kindTh(widget.kind)}แล้ว',
                  postId: widget.postId,
                  postTitle: widget.postTitle,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('จบการ${_kindTh(widget.kind)}แล้ว ขอบคุณสำหรับการให้คะแนน ⭐')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _messageBubble(Map<String, dynamic> m, String myId) {
    final isMe = m['from'] == myId;
    final type = (m['type'] ?? 'text') as String;
    final text = (m['text'] ?? '') as String;

    if (type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (type == 'image') {
      final url = (m['imageUrl'] ?? '') as String;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[const CircleAvatar(radius: 12), const SizedBox(width: 6)],
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // text
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[const CircleAvatar(radius: 12), const SizedBox(width: 6)],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF007AFF) : const Color(0xFFE9E9EB),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final isSelf = myId == widget.peerId;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.peerId).snapshots(),
          builder: (context, snap) {
            final name = snap.data?.data()?['displayName'] as String?;
            final title = name == null || name.isEmpty ? widget.peerId : name;
            return Text('$title (${widget.postTitle})', overflow: TextOverflow.ellipsis);
          },
        ),
        actions: [
          // ⭐ ให้ดาว/รีวิว — กันเจ้าของโพสต์ & กันให้ซ้ำ
          IconButton(
            tooltip: 'ให้ดาว/เขียนรีวิว',
            icon: const Icon(Icons.star_rate_rounded),
            onPressed: () async {
              final myIdNow = FirebaseAuth.instance.currentUser!.uid;

              // 1) อ่านโพสต์สด ๆ เพื่อเอา owner ที่แน่นอน
              final postSnap = await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .get();

              final ownerFromServer = postSnap.data()?['userId'] as String?;
              debugPrint('[RATE] myId=$myIdNow, postId=${widget.postId}, owner=$ownerFromServer');

              // 2) ถ้ามี owner และตรงกับเรา → กันกด พร้อมบอกค่าจริง (กันงง)
              if (ownerFromServer != null && ownerFromServer == myIdNow) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ห้ามให้คะแนนโพสต์ของตัวเอง')),
                );
                return;
              }

              // 3) กัน “ให้ซ้ำ” ก่อนเปิด dialog
              final ratingRef = FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('ratings')
                  .doc(myIdNow);

              final already = await ratingRef.get();
              if (already.exists) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คุณได้ให้คะแนนโพสต์นี้ไปแล้ว')),
                );
                return;
              }

              // 4) เปิด dialog ให้คะแนน/รีวิว (ถ้า owner หาไม่ได้ ก็ปล่อยไป – rules จะกันเองถ้าเป็นเจ้าของจริง)
              if (!mounted) return;
              showRatePostDialog(context, postId: widget.postId);
            },
          ),


          // 📝 ดูรีวิวของโพสต์นี้

          
        ],
      ),
      body: Column(
        children: [
          _postBanner(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.instance.messages(widget.peerId, postId: widget.postId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_listCtrl.hasClients) {
                    _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _listCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => _messageBubble(msgs[i].data(), myId),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'เลือกรูป',
                    onPressed: _uploading ? null : _pickAndSendImage,
                    icon: _uploading
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msg,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: _send,
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
