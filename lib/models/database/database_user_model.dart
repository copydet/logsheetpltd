/// ============================================================================
/// DATABASE USER MODEL
/// ============================================================================
/// Model untuk SQLite database user storage
/// Digunakan untuk local database operations dan offline data
/// ============================================================================

class DatabaseUser {
  final int? id;
  final String username;
  final String displayName;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DatabaseUser({
    this.id,
    required this.username,
    required this.displayName,
    this.role = 'operator',
    this.createdAt,
    this.updatedAt,
  });

  /// Buat DatabaseUser from database map
  factory DatabaseUser.fromMap(Map<String, dynamic> map) {
    return DatabaseUser(
      id: map['id'] as int?,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      role: map['role'] as String? ?? 'operator',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Ubah DatabaseUser to database map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'username': username,
      'display_name': displayName,
      'role': role,
    };

    if (id != null) {
      map['id'] = id;
    }

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }

    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  /// Buat copy with updated fields
  DatabaseUser copyWith({
    int? id,
    String? username,
    String? displayName,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DatabaseUser(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DatabaseUser(id: $id, username: $username, displayName: $displayName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DatabaseUser &&
        other.id == id &&
        other.username == username &&
        other.displayName == displayName &&
        other.role == role;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        username.hashCode ^
        displayName.hashCode ^
        role.hashCode;
  }
}

/// ============================================================================
/// DATABASE USER SESSION MODEL
/// ============================================================================

class DatabaseUserSession {
  final int? id;
  final int userId;
  final String sessionToken;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  DatabaseUserSession({
    this.id,
    required this.userId,
    required this.sessionToken,
    this.isActive = true,
    this.createdAt,
    this.expiresAt,
  });

  factory DatabaseUserSession.fromMap(Map<String, dynamic> map) {
    return DatabaseUserSession(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      sessionToken: map['session_token'] as String,
      isActive: (map['is_active'] as int) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'session_token': sessionToken,
      'is_active': isActive ? 1 : 0,
    };

    if (id != null) {
      map['id'] = id;
    }

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }

    if (expiresAt != null) {
      map['expires_at'] = expiresAt!.toIso8601String();
    }

    return map;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  String toString() {
    return 'DatabaseUserSession(id: $id, userId: $userId, isActive: $isActive, isExpired: $isExpired)';
  }
}
