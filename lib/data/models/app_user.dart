class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  /// เก็บเบอร์แบบเลขล้วน (เช่น 0812345678)
  final String? phone;
  /// เก็บเลขบัตรแบบปิดบังเท่านั้น (ไม่เก็บเลขจริงในโปรไฟล์)
  final String? idMasked;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.phone,
    this.idMasked,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'idMasked': idMasked,
      };
}
