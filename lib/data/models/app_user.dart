class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? phone;
  final String? idMasked; // เก็บเลขบัตรแบบปิดบังในอนาคต

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
        'createdAt': DateTime.now(),
      };
}
