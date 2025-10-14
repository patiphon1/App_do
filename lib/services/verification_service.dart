import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class VerificationService {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;
  final _st = FirebaseStorage.instance;

  String get uid => _auth.currentUser!.uid;

  Future<Map<String, String>> _uploadBoth(XFile front, XFile back) async {
    final frontRef = _st.ref('id-verifications/$uid/front.jpg');
    final backRef  = _st.ref('id-verifications/$uid/back.jpg');

    Uint8List fb = await front.readAsBytes();
    Uint8List bb = await back.readAsBytes();

    await frontRef.putData(fb, SettableMetadata(contentType: 'image/jpeg'));
    await backRef.putData(bb,  SettableMetadata(contentType: 'image/jpeg'));

    final frontUrl = await frontRef.getDownloadURL();
    final backUrl  = await backRef.getDownloadURL();

    return {'frontUrl': frontUrl, 'backUrl': backUrl};
  }

  Future<void> submit(XFile front, XFile back) async {
    final urls = await _uploadBoth(front, back);
    final verRef = _fs.collection('verifications').doc(uid);
    await verRef.set({
      'uid': uid,
      'frontUrl': urls['frontUrl'],
      'backUrl': urls['backUrl'],
      'status': 'pending',
      'reason': null,
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedBy': null,
      'reviewedAt': null,
    }, SetOptions(merge: true));

    await _fs.collection('auditLogs').add({
      'uid': uid, 'action': 'submit', 'by': uid,
      'at': FieldValue.serverTimestamp(), 'note': null
    });
  }
}
