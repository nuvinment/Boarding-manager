/// Role hierarchy: super_admin > manager > staff > boarder
enum UserRole {
  superAdmin,
  manager,
  staff,
  boarder;

  String get dbValue {
    switch (this) {
      case UserRole.superAdmin: return 'super_admin';
      case UserRole.manager:   return 'manager';
      case UserRole.staff:     return 'staff';
      case UserRole.boarder:   return 'boarder';
    }
  }

  static UserRole fromDb(String? val) {
    switch (val) {
      case 'super_admin': return UserRole.superAdmin;
      case 'manager':     return UserRole.manager;
      case 'staff':       return UserRole.staff;
      default:            return UserRole.boarder;
    }
  }

  bool get isManagerOrAbove =>
      this == UserRole.superAdmin || this == UserRole.manager;

  bool get isStaffOrAbove =>
      this == UserRole.superAdmin ||
      this == UserRole.manager ||
      this == UserRole.staff;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin: return 'Super Admin';
      case UserRole.manager:   return 'Manager';
      case UserRole.staff:     return 'Staff';
      case UserRole.boarder:   return 'Boarder';
    }
  }
}

/// Granular staff permissions
enum StaffPermission {
  complaints,
  billing,
  rooms,
  announcements,
  reports;

  String get dbValue => name;
  static StaffPermission? fromDb(String v) {
    for (final p in StaffPermission.values) {
      if (p.dbValue == v) return p;
    }
    return null;
  }
}

/// Boarder / user account status
enum BoarderStatus {
  pendingApproval,
  active,
  inactive;

  String get dbValue {
    switch (this) {
      case BoarderStatus.pendingApproval: return 'pending_approval';
      case BoarderStatus.active:          return 'active';
      case BoarderStatus.inactive:        return 'inactive';
    }
  }

  static BoarderStatus fromDb(String? v) {
    switch (v) {
      case 'pending_approval': return BoarderStatus.pendingApproval;
      case 'active':           return BoarderStatus.active;
      default:                 return BoarderStatus.inactive;
    }
  }
}

class AppUser {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final UserRole role;
  final BoarderStatus status;
  final int? linkedStudentId; // for boarders — links to students table
  final List<StaffPermission> permissions; // for staff role

  const AppUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    required this.status,
    this.linkedStudentId,
    this.permissions = const [],
  });

  factory AppUser.fromMap(
    Map<String, dynamic> map, {
    List<StaffPermission> permissions = const [],
  }) {
    return AppUser(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: UserRole.fromDb(map['role'] as String?),
      status: BoarderStatus.fromDb(map['status'] as String?),
      linkedStudentId: map['linked_student_id'] as int?,
      permissions: permissions,
    );
  }

  /// Returns true when this user can perform [p].
  /// Managers/super-admins have all permissions implicitly.
  bool hasPermission(StaffPermission p) {
    if (role.isManagerOrAbove) return true;
    return permissions.contains(p);
  }
}
