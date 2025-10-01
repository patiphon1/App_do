import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/app_user.dart';

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference get _users => _db.collection('users');

  Future<void> createIfNotExists(AppUser user) async {
    final doc = _users.doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set(user.toMap());
    }
  }
}
