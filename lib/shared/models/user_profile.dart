class UserProfile {
  final String id;
  final String displayName;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
