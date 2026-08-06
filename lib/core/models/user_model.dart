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

  // ── Nuevos campos gamificación y segmentación v1.2.0 ───────
  final String userRole; // 'casual' o 'corporate'
  final bool completedOnboarding;
  final int iguanaLevel;
  final int iguanaPoints;
  final String iguanaPersonality;
  final String iguanaType;
  final String searchCode;

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
    this.userRole = 'casual',
    this.completedOnboarding = false,
    this.iguanaLevel = 1,
    this.iguanaPoints = 0,
    this.iguanaPersonality = 'friendly',
    this.iguanaType = 'non_binary',
    this.searchCode = '',
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

  /// URL absoluta para mostrar la imagen (Supabase Storage / Google entregan URLs http completas)
  String get fullProfileImageUrl {
    if (profileImageUrl.isEmpty) return '';
    if (profileImageUrl.startsWith('http')) return profileImageUrl;
    // Assets locales o rutas relativas legadas del antiguo servidor PHP: sin URL de red
    return '';
  }

  /// ¿Tiene foto de perfil real?
  bool get hasProfileImage =>
      profileImageUrl.isNotEmpty && !profileImageUrl.startsWith('assets/');

  /// ¿Es una imagen de los assets?
  bool get isAssetImage => profileImageUrl.startsWith('assets/');

  /// Nombre del compañero iguana según su tipo
  String get companionName => switch (iguanaType) {
        'male' => 'Drago',
        'female' => 'Eli',
        _ => 'Halo',
      };

  /// Ruta del asset de la imagen de la mascota companion
  String get companionAsset => switch (iguanaType) {
        'male' => 'assets/images/mascota/DRAGO.png',
        'female' => 'assets/images/mascota/ELI.png',
        _ => 'assets/images/mascota/HALO.png',
      };

  // ── Serialización ───────────────────────────────────────────

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Acepta múltiples variantes de nombre (MySQL/Supabase/Mock)
    final name = (json['fullName'] ?? json['name'] ?? json['display_name'] ?? '') as String;
    final profileImageUrl = (json['profileImageUrl'] ?? json['profile_image_url'] ?? '') as String;
    final rating = (json['rating'] as num?)?.toDouble() ?? 0.0;
    final activitiesAttended = (json['activitiesAttended'] ?? json['activities_attended'] as num?)?.toInt() ?? 0;
    final activitiesCreated = (json['activitiesCreated'] ?? json['activities_created'] as num?)?.toInt() ?? 0;
    final isVerified = (json['isVerified'] ?? json['is_verified'] as bool?) ?? false;
    final ageVisible = (json['ageVisible'] ?? json['age_visible'] as bool?) ?? true;
    final setupCompleted = (json['setupCompleted'] ?? json['setup_completed'] as bool?) ?? false;
    final userRole = (json['userRole'] ?? json['user_role'] ?? 'casual') as String;
    final completedOnboarding = (json['completedOnboarding'] ?? json['completed_onboarding'] as bool?) ?? false;
    final iguanaLevel = (json['iguanaLevel'] ?? json['iguana_level'] as num?)?.toInt() ?? 1;
    final iguanaPoints = (json['iguanaPoints'] ?? json['iguana_points'] as num?)?.toInt() ?? 0;
    final iguanaPersonality = (json['iguanaPersonality'] ?? json['iguana_personality'] ?? 'friendly') as String;
    final iguanaType = (json['iguanaType'] ?? json['iguana_type'] ?? 'non_binary') as String;
    final searchCode = (json['searchCode'] ?? json['search_code'] ?? '') as String;
    
    return UserModel(
      id: json['id'] as String,
      name: name,
      profileImageUrl: profileImageUrl,
      rating: rating,
      activitiesAttended: activitiesAttended,
      activitiesCreated: activitiesCreated,
      bio: (json['bio'] ?? '') as String,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'] as List)
          : json['user_interests'] != null
              ? (json['user_interests'] as List)
                  .map((e) => e is Map ? (e['tag'] ?? '').toString() : e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : const [],
      isVerified: isVerified,
      joinedDate: json['joinedDate'] != null
          ? DateTime.tryParse(json['joinedDate'] as String) ?? DateTime.now()
          : json['joined_date'] != null
              ? DateTime.tryParse(json['joined_date'] as String) ?? DateTime.now()
              : DateTime.now(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : json['birth_date'] != null
              ? DateTime.tryParse(json['birth_date'] as String)
              : null,
      gender: json['gender'] != null
          ? UserGender.fromJson(json['gender'] as String)
          : UserGender.preferNotToSay,
      ageVisible: ageVisible,
      authProviders: (json['authProviders'] ?? json['auth_providers'] as List?)
              ?.map((p) => AuthProvider.values.firstWhere(
                    (e) => e.name == p,
                    orElse: () => AuthProvider.email,
                  ))
              .toList() ??
          [AuthProvider.email],
      setupCompleted: setupCompleted,
      userRole: userRole,
      completedOnboarding: completedOnboarding,
      iguanaLevel: iguanaLevel,
      iguanaPoints: iguanaPoints,
      iguanaPersonality: iguanaPersonality,
      iguanaType: iguanaType,
      searchCode: searchCode,
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
      'userRole': userRole,
      'completedOnboarding': completedOnboarding,
      'iguanaLevel': iguanaLevel,
      'iguanaPoints': iguanaPoints,
      'iguanaPersonality': iguanaPersonality,
      'iguanaType': iguanaType,
      'searchCode': searchCode,
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
    String? userRole,
    bool? completedOnboarding,
    int? iguanaLevel,
    int? iguanaPoints,
    String? iguanaPersonality,
    String? iguanaType,
    String? searchCode,
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
      userRole: userRole ?? this.userRole,
      completedOnboarding: completedOnboarding ?? this.completedOnboarding,
      iguanaLevel: iguanaLevel ?? this.iguanaLevel,
      iguanaPoints: iguanaPoints ?? this.iguanaPoints,
      iguanaPersonality: iguanaPersonality ?? this.iguanaPersonality,
      iguanaType: iguanaType ?? this.iguanaType,
      searchCode: searchCode ?? this.searchCode,
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
