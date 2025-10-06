import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadPostImage(File file, String uid) async {
    final path = 'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref  = _storage.ref(path);
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteByUrl(String url) async {
    await _storage.refFromURL(url).delete();
  }
}
