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

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'].toString(),
        refreshToken: json['refreshToken'].toString(),
      );
}

class AccountModel {
  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.currentBalance,
    required this.icon,
  });

  final String id;
  final String name;
  final String type;
  final String currency;
  final double currentBalance;
  final String icon;

  factory AccountModel.fromJson(Map<String, dynamic> json) => AccountModel(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        type: (json['type'] ?? 'cash').toString(),
        currency: (json['currency'] ?? 'PKR').toString(),
        currentBalance: (json['currentBalance'] ?? 0).toDouble(),
        icon: (json['icon'] ?? 'wallet').toString(),
      );
}
