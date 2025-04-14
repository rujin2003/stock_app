class User {
  final String id;
  final DateTime registrationDate;
  final double? accountBalance;
  final int? activeTrades;
  final bool isVerified;
  final String email;
  final String firstName;
  final String lastName;
  final String? birthday;
  final String? country;
  final String? gender;
  final String? number;
  final String? address;
  final String? city;
  final String? zipcode;
  final String? document1Type;
  final String? document2Type;
  final String? document1;
  final String? document2;
 

  User({
    required this.id,
    required this.registrationDate,
    this.accountBalance,
    this.activeTrades,
    required this.isVerified,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.birthday,
    this.country,
    this.gender,
    this.number,
    this.address,
    this.city,
    this.zipcode,
    this.document1Type,
    this.document2Type,
    this.document1,
    this.document2,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'],
      registrationDate: DateTime.parse(json['registration_date']),
      accountBalance: json['account_balance'] != null ? (json['account_balance'] as num).toDouble() : null,
      activeTrades: json['active_trades'],
      isVerified: json['is_kyc_verified'] ?? false,
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      birthday: json['birthday'],
      country: json['country'],
      gender: json['gender'],
      number: json['number']?.toString(),
      address: json['address'],
      city: json['city'],
      zipcode: json['zipcode'],
      document1Type: json['document1_type'],
      document2Type: json['document2_type'],
      document1: json['document1'],
      document2: json['document2'],
    );
  }

  String get name => firstName.isNotEmpty ? '$firstName $lastName' : 'Unknown User';
}
