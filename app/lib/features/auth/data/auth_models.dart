class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.avatarUrl,
    required this.isVerified,
    required this.onboardingStage,
    required this.currency,
    required this.themePreference,
  });

  final String id;
  final String email;
  final String fullName;
  final String phone;
  // Holds a local file path (not a URL) now that avatars are stored on
  // device instead of uploaded — the field name stayed the same to avoid
  // rippling a rename through every screen that reads it.
  final String avatarUrl;
  final bool isVerified;
  final String onboardingStage; // profile | account | done
  final String currency;
  final String themePreference;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final settings = (json['settings'] ?? {}) as Map;
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      isVerified: json['isVerified'] == true,
      onboardingStage: (json['onboardingStage'] ?? 'profile').toString(),
      currency: (settings['currency'] ?? 'PKR').toString(),
      themePreference: (settings['theme'] ?? 'system').toString(),
    );
  }
}
