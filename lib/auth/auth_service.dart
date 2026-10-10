import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_service.dart';
import '../models/user_model.dart';

/// Central authentication service.
/// - Managers / Super-admins use a PIN (hashed SHA-256 + salt).
/// - Boarders use email + password.
/// - Session is persisted in SharedPreferences.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _keyUserId    = 'auth_user_id';
  static const _keyUserRole  = 'auth_user_role';
  static const _keyUserName  = 'auth_user_name';

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // -----------------------------------------------------------------------
  // Session helpers
  // -----------------------------------------------------------------------

  /// Restore session from SharedPreferences on app launch.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id   = prefs.getInt(_keyUserId);
    if (id == null) return false;

    try {
      final db = DatabaseService.instance;
      final user = await db.getUserById(id);
      if (user == null) {
        await clearSession();
        return false;
      }
      _currentUser = user;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId,   user.id);
    await prefs.setString(_keyUserRole, user.role.dbValue);
    await prefs.setString(_keyUserName, user.name);
    _currentUser = user;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserName);
    _currentUser = null;
  }

  // -----------------------------------------------------------------------
  // Hashing
  // -----------------------------------------------------------------------

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    final ts = DateTime.now().microsecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode(ts)).toString().substring(0, 16);
  }

  // -----------------------------------------------------------------------
  // Login — PIN (manager / staff / super_admin)
  // -----------------------------------------------------------------------

  /// Login via email + PIN. Returns the authenticated [AppUser].
  Future<AppUser> loginWithPin({
    required String email,
    required String pin,
  }) async {
    final db = DatabaseService.instance;
    final row = await db.getUserByEmail(email);
    if (row == null) throw Exception('No account found for this email.');

    final role = UserRole.fromDb(row['role'] as String?);
    if (role == UserRole.boarder) {
      throw Exception('Boarders must use the email + password login.');
    }

    final salt       = row['password_salt'] as String? ?? '';
    final storedHash = row['password_hash'] as String? ?? '';
    final entered    = hashPin(pin, salt);

    if (entered != storedHash) throw Exception('Incorrect PIN. Please try again.');

    final status = BoarderStatus.fromDb(row['status'] as String?);
    if (status != BoarderStatus.active) {
      throw Exception('Your account is not active. Contact the administrator.');
    }

    final permissions = await db.getStaffPermissions(row['id'] as int);
    final user = AppUser.fromMap(row, permissions: permissions);
    await _saveSession(user);
    return user;
  }

  // -----------------------------------------------------------------------
  // Login — Email + Password (boarders)
  // -----------------------------------------------------------------------

  Future<AppUser> loginBoarder({
    required String email,
    required String password,
  }) async {
    final db  = DatabaseService.instance;
    final row = await db.getUserByEmail(email);
    if (row == null) throw Exception('No account found for this email.');

    final role = UserRole.fromDb(row['role'] as String?);
    if (role != UserRole.boarder) {
      throw Exception('Please use the staff/manager login.');
    }

    final salt       = row['password_salt'] as String? ?? '';
    final storedHash = row['password_hash'] as String? ?? '';
    final entered    = hashPassword(password, salt);

    if (entered != storedHash) throw Exception('Incorrect password. Please try again.');

    final status = BoarderStatus.fromDb(row['status'] as String?);
    if (status == BoarderStatus.pendingApproval) {
      // Still let them "log in" but flag it — router will show waiting page
    } else if (status == BoarderStatus.inactive) {
      throw Exception('Your account has been deactivated. Contact the manager.');
    }

    final user = AppUser.fromMap(row);
    await _saveSession(user);
    return user;
  }

  // -----------------------------------------------------------------------
  // Boarder self-signup
  // -----------------------------------------------------------------------

  Future<void> registerBoarder({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final db = DatabaseService.instance;
    // Check uniqueness
    final existing = await db.getUserByEmail(email);
    if (existing != null) throw Exception('This email is already registered.');

    final salt = generateSalt();
    final hash = hashPassword(password, salt);

    await db.createUser(
      name: name,
      email: email,
      phone: phone,
      role: UserRole.boarder,
      status: BoarderStatus.pendingApproval,
      passwordHash: hash,
      passwordSalt: salt,
    );
  }

  // -----------------------------------------------------------------------
  // Manager creates staff / manager accounts
  // -----------------------------------------------------------------------

  Future<void> createStaffAccount({
    required String name,
    required String email,
    required String phone,
    required String pin,
    required UserRole role,
    required List<StaffPermission> permissions,
  }) async {
    final db = DatabaseService.instance;
    final existing = await db.getUserByEmail(email);
    if (existing != null) throw Exception('Email already registered.');

    final salt = generateSalt();
    final hash = hashPin(pin, salt);

    final userId = await db.createUser(
      name: name,
      email: email,
      phone: phone,
      role: role,
      status: BoarderStatus.active,
      passwordHash: hash,
      passwordSalt: salt,
    );

    if (role == UserRole.staff && permissions.isNotEmpty) {
      await db.setStaffPermissions(userId, permissions);
    }
  }

  // -----------------------------------------------------------------------
  // Change PIN (for staff/manager)
  // -----------------------------------------------------------------------

  Future<void> changePin({
    required int userId,
    required String currentPin,
    required String newPin,
  }) async {
    final db = DatabaseService.instance;
    // Delegate entirely to the db method which has the correct hash/salt logic
    await db.changeUserPin(
      userId: userId,
      currentPin: currentPin,
      newPin: newPin,
      hashFn: hashPin,
    );
  }

  // -----------------------------------------------------------------------
  // Logout
  // -----------------------------------------------------------------------

  Future<void> logout() async => clearSession();
}
