class UserData {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String country;
  final String gender;
  final String mobile;
  final String address;
  final String city;
  final String zipCode;
  final bool isVerified;
  final DateTime createdAt;

  UserData({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.country,
    required this.gender,
    required this.mobile,
    required this.address,
    required this.city,
    required this.zipCode,
    this.isVerified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'birth_date': birthDate.toIso8601String(),
        'country': country,
        'gender': gender,
        'mobile': mobile,
        'address': address,
        'city': city,
        'zip_code': zipCode,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String()
      };

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        id: json['id'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        birthDate: DateTime.parse(json['birth_date']),
        country: json['country'],
        gender: json['gender'],
        mobile: json['mobile'],
        address: json['address'],
        city: json['city'],
        zipCode: json['zip_code'],
        isVerified: json['is_verified'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );
}
