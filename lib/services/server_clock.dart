import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServerClock {
  static int _offsetMs = 0; // serverNow - deviceNow

  /// เรียก sync เวลากับเซิร์ฟเวอร์ (ควรทำตอน start app)
  static Future<void> sync() async {
    try {
      final deviceMs = DateTime.now().millisecondsSinceEpoch;

      final callable = FirebaseFunctions.instance.httpsCallable('serverNow');
      final res = await callable.call();

      final serverMs = (res.data['now'] as num).toInt();
      _offsetMs = serverMs - deviceMs;
      print('✅ ServerClock sync success, offset $_offsetMs ms');
    } catch (e) {
      // ถ้าเรียกไม่ได้ เช่น ยังไม่ได้ deploy function หรือเน็ตล่ม
      print('⚠️ ServerClock sync error: $e');
      _offsetMs = 0;
    }
  }

  /// คืนค่าเวลาปัจจุบัน (Timestamp) ตามเซิร์ฟเวอร์
  static Timestamp now() {
    final ms = DateTime.now().millisecondsSinceEpoch + _offsetMs;
    return Timestamp.fromMillisecondsSinceEpoch(ms);
  }
}
