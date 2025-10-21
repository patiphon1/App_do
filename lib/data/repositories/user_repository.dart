import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// ผลลัพธ์จากการจอง unique ภายในทรานแซกชัน
class UniqueReservationResult {
  final bool ok;
  final String? code;     // 'idcard-in-use' | 'phone-in-use'
  final String? message;  // ข้อความไทยสำหรับโชว์ผู้ใช้
  const UniqueReservationResult(this.ok, {this.code, this.message});
}

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();

  final _fire = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users   => _fire.collection('users');
  CollectionReference<Map<String, dynamic>> get _uniques => _fire.collection('uniques');

  /// (คงไว้ใช้ที่อื่น) สร้างผู้ใช้แบบธรรมดา
  Future<void> createIfNotExists(AppUser u) async {
    final ref = _users.doc(u.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        ...u.toMap(),
        'photoURL'   : '',
        'bio'        : '',
        'ratingSum'  : 0,
        'ratingCount': 0,
        'ratingAvg'  : 0,
        'starsTotal' : 0,
        'starsRaters': 0,
        'starsCount' : 0,
        'verified'   : false,
        'createdAt'  : FieldValue.serverTimestamp(),
        'updatedAt'  : FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        ...u.toMap(),
        'updatedAt'  : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// ✅ เวอร์ชันใหม่: ทำทุกอย่างใน Transaction โดย "ไม่ throw ใน callback"
  /// - ถ้าซ้ำ จะ `return UniqueReservationResult(false, code: ...)`
  /// - ถ้าไม่ซ้ำ → เขียน uniques + users แล้ว `return UniqueReservationResult(true)`
  Future<UniqueReservationResult> createWithUniques(
    AppUser u, {
    String? rawIdCard,  // 13 หลัก (เลขล้วน)
    String? rawPhone,   // 10 หลัก (เลขล้วน)
  }) async {
    return _fire.runTransaction<UniqueReservationResult>((txn) async {
      final userRef = _users.doc(u.uid);

      bool idTaken = false, phoneTaken = false;

      // ตรวจซ้ำ (ยังไม่เขียน)
      DocumentReference<Map<String, dynamic>>? idRef;
      if (rawIdCard != null && rawIdCard.isNotEmpty) {
        idRef = _uniques.doc('id_$rawIdCard');
        final snap = await txn.get(idRef);
        idTaken = snap.exists;
      }

      DocumentReference<Map<String, dynamic>>? phRef;
      if (rawPhone != null && rawPhone.isNotEmpty) {
        phRef = _uniques.doc('phone_$rawPhone');
        final snap = await txn.get(phRef);
        phoneTaken = snap.exists;
      }

      // ถ้ามีอย่างใดอย่างหนึ่งซ้ำ -> คืนผลลัพธ์ (ไม่เขียนอะไร) โดยไม่ throw
      if (idTaken || phoneTaken) {
        if (idTaken) {
          return const UniqueReservationResult(false,
              code: 'idcard-in-use', message: 'เลขบัตรประชาชนนี้ถูกใช้แล้ว');
        }
        if (phoneTaken) {
          return const UniqueReservationResult(false,
              code: 'phone-in-use', message: 'เบอร์โทรศัพท์นี้ถูกใช้แล้ว');
        }
      }

      // เขียน uniques
      if (idRef != null) {
        txn.set(idRef, {
          'uid': u.uid,
          'type': 'idCard',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (phRef != null) {
        txn.set(phRef, {
          'uid': u.uid,
          'type': 'phone',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // เขียนโปรไฟล์ผู้ใช้
      txn.set(userRef, {
        ...u.toMap(),
        'photoURL'   : '',
        'bio'        : '',
        'ratingSum'  : 0,
        'ratingCount': 0,
        'ratingAvg'  : 0,
        'starsTotal' : 0,
        'starsRaters': 0,
        'starsCount' : 0,
        'verified'   : false,
        'createdAt'  : FieldValue.serverTimestamp(),
        'updatedAt'  : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return const UniqueReservationResult(true);
    });
  }
}
