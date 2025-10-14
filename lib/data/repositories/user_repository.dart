import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();
  final _fire = FirebaseFirestore.instance;

  Future<void> createIfNotExists(AppUser u) async {
    final ref = _fire.collection('users').doc(u.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid'         : u.uid,
        'email'       : u.email,
        'displayName' : u.displayName,
        'phone'       : u.phone ?? '',
        // ช่องเผื่ออนาคต (ยังไม่มีใน AppUser แต่อยากให้มีใน DB)
        'photoURL'    : '',
        'bio'         : '',
        // ค่าเริ่มต้นสรุปดาว/เรตติ้ง
        'ratingSum'   : 0,
        'ratingCount' : 0,
        'ratingAvg'   : 0,
        'starsTotal'  : 0,
        'starsRaters' : 0,
        'starsCount'  : 0,
        'verified'    : false,
        'createdAt'   : FieldValue.serverTimestamp(),
        'updatedAt'   : FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'displayName' : u.displayName,
        'email'       : u.email,
        'phone'       : u.phone ?? '',
        'updatedAt'   : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
