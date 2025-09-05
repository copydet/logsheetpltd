import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
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

  UserModel({
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
  });

  /// Buat UserModel dari Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'operator',
      isActive: data['isActive'] == 'true' || data['isActive'] == true,
      generatorAccess: List<String>.from(data['generatorAccess'] ?? []),
      permissions: UserPermissions.fromMap(data['permissions'] ?? {}),
      createdAt: _parseTimestamp(data['createdAt']),
      lastLogin: _parseTimestamp(data['lastLogin']),
    );
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
    return 'UserModel(uid: $uid, username: $username, role: $role)';
  }
}

class UserPermissions {
  final bool canEditLogsheets;
  final bool canExportData;
  final bool canViewAllGenerators;
  final bool canManageUsers;

  UserPermissions({
    required this.canEditLogsheets,
    required this.canExportData,
    required this.canViewAllGenerators,
    required this.canManageUsers,
  });

  factory UserPermissions.fromMap(Map<String, dynamic> data) {
    return UserPermissions(
      canEditLogsheets: data['canEditLogsheets'] ?? false,
      canExportData: data['canExportData'] ?? false,
      canViewAllGenerators: data['canViewAllGenerators'] ?? false,
      canManageUsers: data['canManageUsers'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canEditLogsheets': canEditLogsheets,
      'canExportData': canExportData,
      'canViewAllGenerators': canViewAllGenerators,
      'canManageUsers': canManageUsers,
    };
  }

  /// Default permissions untuk operator
  factory UserPermissions.operator() {
    return UserPermissions(
      canEditLogsheets: true,
      canExportData: true,
      canViewAllGenerators: true,
      canManageUsers: false,
    );
  }

  /// Default permissions untuk admin
  factory UserPermissions.admin() {
    return UserPermissions(
      canEditLogsheets: true,
      canExportData: true,
      canViewAllGenerators: true,
      canManageUsers: true,
    );
  }

  @override
  String toString() {
    return 'UserPermissions(edit: $canEditLogsheets, export: $canExportData, viewAll: $canViewAllGenerators, manage: $canManageUsers)';
  }
}
