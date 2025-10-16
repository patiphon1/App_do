import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadPostImage(File file, String uid) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'posts/$uid/$fileName';
    final ref = _storage.ref(path);

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await task.ref.getDownloadURL();
  }

  Future<void> deleteByUrl(String url) async {
    await _storage.refFromURL(url).delete();
  }
}
