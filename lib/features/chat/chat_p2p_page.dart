import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';

class ChatP2PPage extends StatefulWidget {
  const ChatP2PPage({
    super.key,
    required this.peerName,
    required this.peerId,
    required this.kind, // 'donate' | 'request' | 'swap'
  });

  final String peerName;
  final String peerId; // UID ของอีกฝั่ง
  final String kind;

  @override
  State<ChatP2PPage> createState() => _ChatP2PPageState();
}

class _ChatP2PPageState extends State<ChatP2PPage> {
  final _msg = TextEditingController();
  final _listCtrl = ScrollController(); // <<< เพิ่ม

  void _send() async {
    final txt = _msg.text.trim();
    if (txt.isEmpty) return;
    _msg.clear();
    await ChatService.instance.sendMessage(
      peerId: widget.peerId,
      text: txt,
      kind: widget.kind,
    );
    // เลื่อนลงล่างสุดหลังส่ง
    await Future.delayed(const Duration(milliseconds: 50));
    if (_listCtrl.hasClients) {
      _listCtrl.animateTo(
        _listCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(radius: 18),
            const SizedBox(width: 10),
            Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.instance.messages(widget.peerId), 
              // *** แนะนำ: ให้ service ทำ .orderBy('sentAt') (ASC) ไว้แล้ว
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!.docs;

                // auto-scroll เมื่อมีข้อความใหม่
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
                    final ts = m['createdAt'] as Timestamp?; 
                    final time = ts != null
                        ? TimeOfDay.fromDateTime(ts.toDate()).format(context)
                        : '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            const CircleAvatar(radius: 12), // อวาตาร์อีกฝั่ง
                            const SizedBox(width: 6),
                          ],
                          // บับเบิล
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF007AFF) // ฟ้า เจ้าของ
                                      : const Color(0xFFE9E9EB), // เทา อีกฝั่ง
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
                          // เวลาเล็ก ๆ ข้างบับเบิล
                          if (time.isNotEmpty)
                            Text(time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                )),
                          if (isMe) const SizedBox(width: 6),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ----- แถบพิมพ์ข้อความ -----
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
                      onSubmitted: (_) => _send(), // กด Enter เพื่อส่ง
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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

