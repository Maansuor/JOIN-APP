import '../services/api_client.dart';

/// Proveedor de autenticación
enum AuthProvider { email, google, facebook, apple }

/// Género (opcional)
enum UserGender {
  male,
  female,
  nonBinary,
  preferNotToSay;

  String toJson() => switch (this) {
        UserGender.male => 'male',
        UserGender.female => 'female',
        UserGender.nonBinary => 'non_binary',
        UserGender.preferNotToSay => 'prefer_not_to_say',
      };

  static UserGender fromJson(String value) => switch (value) {
        'male' => UserGender.male,
        'female' => UserGender.female,
        'non_binary' => UserGender.nonBinary,
        _ => UserGender.preferNotToSay,
      };

  String get label => switch (this) {
        UserGender.male => 'Masculino',
        UserGender.female => 'Femenino',
        UserGender.nonBinary => 'No binario',
        UserGender.preferNotToSay => 'Prefiero no decir',
      };
}

/// Modelo de Usuario para Join
class UserModel {
  final String id;
  final String name;
  final String profileImageUrl;
  final double rating; // 0-5
  final int activitiesAttended;
  final int activitiesCreated;
  final String bio;
  final List<String> interests;
  final bool isVerified;
  final DateTime joinedDate;
  final String? email;
  final String? phone;

  // ── Nuevos campos v1.1.0 ────────────────────────────────────
  /// Fecha de nacimiento — la edad se calcula en tiempo real
  final DateTime? birthDate;

  /// Género (opcional)
  final UserGender gender;

  /// ¿Mostrar edad en perfil público?
  final bool ageVisible;

  /// Proveedor(es) de autenticación vinculados
  final List<AuthProvider> authProviders;

  /// ¿El usuario completó el onboarding?
  final bool setupCompleted;

  const UserModel({
    required this.id,
    required this.name,
    required this.profileImageUrl,
    required this.rating,
    required this.activitiesAttended,
    required this.activitiesCreated,
    required this.bio,
    required this.interests,
    required this.isVerified,
    required this.joinedDate,
    this.email,
    this.phone,
    this.birthDate,
    this.gender = UserGender.preferNotToSay,
    this.ageVisible = true,
    this.authProviders = const [AuthProvider.email],
    this.setupCompleted = false,
  });

  // ── Getters calculados ──────────────────────────────────────

  /// Edad actual calculada desde birthDate
  int? get age {
    if (birthDate == null) return null;
    final today = DateTime.now();
    int years = today.year - birthDate!.year;
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      years--;
    }
    return years;
  }

  /// ¿Es mayor de 18 años?
  bool get isAdult => (age ?? 0) >= 18;

  /// Edad pública (respeta la preferencia de privacidad)
  int? get publicAge => ageVisible ? age : null;

  /// Iniciales para avatar placeholder
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// URL absoluta para mostrar la imagen (maneja Google vs Servidor Propio)
  String get fullProfileImageUrl {
    if (profileImageUrl.isEmpty) return '';
    if (profileImageUrl.startsWith('http')) return profileImageUrl;
    if (profileImageUrl.startsWith('assets/')) {
      return ''; // No concatenar para assets locales
    }

    final base = ApiClient.instance.baseUrl.replaceAll('/api', '');
    return '$base/$profileImageUrl';
  }

  /// ¿Tiene foto de perfil real?
  bool get hasProfileImage =>
      profileImageUrl.isNotEmpty && !profileImageUrl.startsWith('assets/');

  /// ¿Es una imagen de los assets?
  bool get isAssetImage => profileImageUrl.startsWith('assets/');

  // ── Serialización ───────────────────────────────────────────

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // 'name' = mock format, 'fullName' = backend PHP format
    final name = (json['fullName'] ?? json['name'] ?? '') as String;
    return UserModel(
      id: json['id'] as String,
      name: name,
      profileImageUrl: (json['profileImageUrl'] ?? '') as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      activitiesAttended: (json['activitiesAttended'] as num?)?.toInt() ?? 0,
      activitiesCreated: (json['activitiesCreated'] as num?)?.toInt() ?? 0,
      bio: (json['bio'] ?? '') as String,
      interests: List<String>.from(json['interests'] as List? ?? []),
      isVerified: json['isVerified'] as bool? ?? false,
      joinedDate: json['joinedDate'] != null
          ? DateTime.tryParse(json['joinedDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      gender: json['gender'] != null
          ? UserGender.fromJson(json['gender'] as String)
          : UserGender.preferNotToSay,
      ageVisible: json['ageVisible'] as bool? ?? true,
      authProviders: (json['authProviders'] as List?)
              ?.map((p) => AuthProvider.values.firstWhere(
                    (e) => e.name == p,
                    orElse: () => AuthProvider.email,
                  ))
              .toList() ??
          [AuthProvider.email],
      setupCompleted: json['setupCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'rating': rating,
      'activitiesAttended': activitiesAttended,
      'activitiesCreated': activitiesCreated,
      'bio': bio,
      'interests': interests,
      'isVerified': isVerified,
      'joinedDate': joinedDate.toIso8601String(),
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      'gender': gender.toJson(),
      'ageVisible': ageVisible,
      'authProviders': authProviders.map((p) => p.name).toList(),
      'setupCompleted': setupCompleted,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? profileImageUrl,
    double? rating,
    int? activitiesAttended,
    int? activitiesCreated,
    String? bio,
    List<String>? interests,
    bool? isVerified,
    DateTime? joinedDate,
    String? email,
    String? phone,
    DateTime? birthDate,
    UserGender? gender,
    bool? ageVisible,
    List<AuthProvider>? authProviders,
    bool? setupCompleted,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      rating: rating ?? this.rating,
      activitiesAttended: activitiesAttended ?? this.activitiesAttended,
      activitiesCreated: activitiesCreated ?? this.activitiesCreated,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      isVerified: isVerified ?? this.isVerified,
      joinedDate: joinedDate ?? this.joinedDate,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      ageVisible: ageVisible ?? this.ageVisible,
      authProviders: authProviders ?? this.authProviders,
      setupCompleted: setupCompleted ?? this.setupCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, age: $age, provider: ${authProviders.map((p) => p.name).join(",")})';
}
