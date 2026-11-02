class User {
  final int id;
  final String email;
  final String displayName;
  final String? enrollmentId;
  final String? phone;
  final String? hostel;
  final String? room;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.enrollmentId,
    this.phone,
    this.hostel,
    this.room,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      enrollmentId: json['enrollment_id'] ?? json['enrollmentId'],
      phone: json['phone'],
      hostel: json['hostel'],
      room: json['room'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'enrollmentId': enrollmentId,
      'phone': phone,
      'hostel': hostel,
      'room': room,
    };
  }
}
