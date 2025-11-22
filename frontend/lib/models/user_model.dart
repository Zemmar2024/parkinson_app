class User {
  final int id;
  final String username;
  final bool isAdmin;

  User({required this.id, required this.username, required this.isAdmin});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      isAdmin: json['is_admin'] ?? false,
    );
  }
}