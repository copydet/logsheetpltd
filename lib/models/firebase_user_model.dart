import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// FIREBASE USER MODEL
/// ============================================================================
/// Model untuk Firebase Authentication & Firestore user profiles
/// Digunakan untuk login, session management, dan cloud user data
/// ============================================================================

class FirebaseUserModel {
  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String role;
  final bool isActive;
  final List<String> generatorAccess;
  final UserPermissions permissions;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final DateTime? updatedAt;
  final DateTime? updateAt; // Support field dari Firebase user

  FirebaseUserModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.generatorAccess,
    required this.permissions,
    this.createdAt,
    this.lastLogin,
    this.updatedAt,
    this.updateAt,
  });

  /// Buat FirebaseUserModel dari Firestore document
  factory FirebaseUserModel.fromFirestore(
    Map<String, dynamic> data,
    String uid,
  ) {
    return FirebaseUserModel(
      uid: uid,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'operator',
      isActive: _parseBoolean(data['isActive']),
      generatorAccess: List<String>.from(data['generatorAccess'] ?? []),
      permissions: UserPermissions.fromMap(data['permissions'] ?? {}),
      createdAt: _parseTimestamp(data['createdAt']),
      lastLogin: _parseTimestamp(data['lastLogin']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      updateAt: _parseTimestamp(data['updateAt']),
    );
  }

  /// Parse boolean dari string atau boolean
  static bool _parseBoolean(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  /// Parse Firestore timestamp ke DateTime
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }

    return null;
  }

  /// Ubah ke Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName,
      'email': email,
      'role': role,
      'isActive': isActive,
      'generatorAccess': generatorAccess,
      'permissions': permissions.toMap(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updateAt': updateAt != null ? Timestamp.fromDate(updateAt!) : null,
    };
  }

  /// Cek apakah user punya akses ke generator tertentu
  bool hasGeneratorAccess(String generatorName) {
    return generatorAccess.contains(generatorName) ||
        permissions.canViewAllGenerators;
  }

  /// Ambil display info untuk UI
  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'operator':
        return 'Operator';
      case 'manager':
        return 'Manager';
      case 'supervisor':
        return 'Supervisor';
      default:
        return role;
    }
  }

  @override
  String toString() {
    return 'FirebaseUserModel(uid: $uid, username: $username, role: $role)';
  }
}

class UserPermissions {
  final bool canEditLogsheets;
  final bool canExportData;
  final bool canViewAllGenerators;
  final bool canManageUsers;
  final bool canConfigureSystem;
  final bool canDeleteEntries;
  final bool canViewAnalytics;
  final bool canViewReports;

  UserPermissions({
    required this.canEditLogsheets,
    required this.canExportData,
    required this.canViewAllGenerators,
    required this.canManageUsers,
    required this.canConfigureSystem,
    required this.canDeleteEntries,
    required this.canViewAnalytics,
    required this.canViewReports,
  });

  factory UserPermissions.fromMap(Map<String, dynamic> data) {
    return UserPermissions(
      canEditLogsheets:
          data['canEditLogsheets'] ?? data['canEditLogsheet'] ?? false,
      canExportData: data['canExportData'] ?? false,
      canViewAllGenerators: data['canViewAllGenerators'] ?? false,
      canManageUsers: data['canManageUsers'] ?? false,
      canConfigureSystem: data['canConfigureSystem'] ?? false,
      canDeleteEntries: data['canDeleteEntries'] ?? false,
      canViewAnalytics: data['canViewAnalytics'] ?? false,
      canViewReports: data['canViewReports'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canEditLogsheets': canEditLogsheets,
      'canExportData': canExportData,
      'canViewAllGenerators': canViewAllGenerators,
      'canManageUsers': canManageUsers,
      'canConfigureSystem': canConfigureSystem,
      'canDeleteEntries': canDeleteEntries,
      'canViewAnalytics': canViewAnalytics,
      'canViewReports': canViewReports,
    };
  }

  /// Default permissions untuk operator
  factory UserPermissions.operator() {
    return UserPermissions(
      canEditLogsheets: true,
      canExportData: true,
      canViewAllGenerators: true,
      canManageUsers: false,
      canConfigureSystem: false,
      canDeleteEntries: false,
      canViewAnalytics: false,
      canViewReports: false,
    );
  }

  /// Default permissions untuk admin
  factory UserPermissions.admin() {
    return UserPermissions(
      canEditLogsheets: true,
      canExportData: true,
      canViewAllGenerators: true,
      canManageUsers: true,
      canConfigureSystem: true,
      canDeleteEntries: true,
      canViewAnalytics: true,
      canViewReports: true,
    );
  }

  @override
  String toString() {
    return 'UserPermissions(edit: $canEditLogsheets, export: $canExportData, viewAll: $canViewAllGenerators, manage: $canManageUsers, config: $canConfigureSystem, delete: $canDeleteEntries, analytics: $canViewAnalytics, reports: $canViewReports)';
  }
}
