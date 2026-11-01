import 'package:get/get.dart';

class UserModel {
  final String token;
  final String type;
  final int id;
  final int? employeId;
  final String username;
  final String? email;
  final String? photo;
  final List<String> roles;
  final bool changePwd;

  UserModel({
    required this.token,
    this.type = 'Bearer',
    required this.id,
    this.employeId,
    required this.username,
    this.email,
    this.photo,
    required this.roles,
    this.changePwd = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      token: json['token']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Bearer',
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      employeId: json['employeId'] is int
          ? json['employeId']
          : int.tryParse(json['employeId']?.toString() ?? ''),
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      photo: json['photo']?.toString(),
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      changePwd: json['changePwd'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'type': type,
      'id': id,
      'employeId': employeId,
      'username': username,
      'email': email,
      'photo': photo,
      'roles': roles,
      'changePwd': changePwd,
    };
  }

  UserModel copyWith({
    String? token,
    String? type,
    int? id,
    int? employeId,
    String? username,
    String? email,
    String? photo,
    List<String>? roles,
    bool? changePwd,
  }) {
    return UserModel(
      token: token ?? this.token,
      type: type ?? this.type,
      id: id ?? this.id,
      employeId: employeId ?? this.employeId,
      username: username ?? this.username,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      roles: roles ?? this.roles,
      changePwd: changePwd ?? this.changePwd,
    );
  }

  // ==================== HELPERS DE DROITS / PERMISSIONS ====================
  bool hasRole(String role) => roles.contains(role);
  bool hasAuthority(String auth) => roles.contains(auth) || isAdmin;

  bool get isAdmin => hasRole('ROLE_ADMIN');
  bool get canAccessOr => hasAuthority('ORDRE_REPARATION');
  bool get canAccessVehicules => hasAuthority('VEHICULES');
  bool get canAccessVidanges => hasAuthority('VIDANGES');
  bool get canAccessDemandesAchats =>
      hasAuthority('BON_ACHAT') ||
      hasAuthority('BON_ACHAT_GENERER') ||
      hasAuthority('BON_ACHAT_VALIDER');

  /// Renvoie UNIQUEMENT les rôles (ex: ROLE_ADMIN, ROLE_CHEF_ATELIER)
  /// et EXCLUT les dizaines de permissions/droits individuels (ex: AFFECTATIONS_VEHICULES, AUDIT_DOR...)
  List<String> get userRoles {
    final filtered = roles.where((r) => r.startsWith('ROLE_')).toList();
    if (filtered.isEmpty && roles.isNotEmpty) {
      // Fallback si pas de préfixe ROLE_
      return ['Utilisateur'];
    }
    return filtered;
  }

  static String formatRole(String role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'Administrateur';
      case 'ROLE_CHEF_ATELIER':
        return 'Chef d\'Atelier';
      case 'ROLE_SUPPORT_ACHAT_APPRO':
        return 'Support Achat & Appro';
      case 'ROLE_MAGASINIER':
        return 'Magasinier';
      case 'ROLE_CHAUFFEUR':
        return 'Chauffeur';
      case 'ROLE_MECANICIEN':
        return 'Mécanicien';
      case 'ROLE_RESPONSABLE_PARC':
        return 'Responsable de Parc';
      case 'ROLE_USER':
        return 'Utilisateur';
      default:
        return role
                .replaceFirst('ROLE_', '')
                .replaceAll('_', ' ')
                .toLowerCase()
                .capitalizeFirst ??
            role;
    }
  }
}
