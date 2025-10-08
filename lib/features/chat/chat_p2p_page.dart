import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';

class ChatP2PPage extends StatefulWidget {
  const ChatP2PPage({
    super.key,
    required this.peerId,
    required this.kind,
    required this.postId,
    required this.postTitle,
  });

  final String peerId;
  final String kind;
  final String postId;
  final String postTitle;

  @override
  State<ChatP2PPage> createState() => _ChatP2PPageState();
}

class _ChatP2PPageState extends State<ChatP2PPage> {
  final _msg = TextEditingController();
  final _listCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    ChatService.instance.ensureChat(
      peerId: widget.peerId,
      kind: widget.kind,
      postId: widget.postId,
      postTitle: widget.postTitle,
    );
  }

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

  String _kindTh(String k) => switch (k) {
        'donate' => 'บริจาค',
        'request' => 'ขอรับ',
        'swap' => 'แลกเปลี่ยน',
        _ => k
      };

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
          if (!isSelf)
            IconButton(
              icon: const Icon(Icons.flag_circle_outlined, color: Colors.redAccent),
              tooltip: 'จบการ${_kindTh(widget.kind)}',
              onPressed: _endChatDialog,
            ),
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
                  itemBuilder: (context, i) {
                    final m = msgs[i].data();
                    final isMe = m['from'] == myId;
                    final text = (m['text'] ?? '') as String;
                    final type = (m['type'] ?? 'text') as String;
                    final ts = m['createdAt'] as Timestamp?;
                    final time = ts != null
                        ? TimeOfDay.fromDateTime(ts.toDate()).format(context)
                        : '';

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

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            const CircleAvatar(radius: 12),
                            const SizedBox(width: 6),
                          ],
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
                          const SizedBox(width: 6),
                          if (time.isNotEmpty)
                            Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          if (isMe) const SizedBox(width: 6),
                        ],
                      ),
                    );
                  },
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
