import 'database_service.dart';
import 'models/user_model.dart';
import 'auth/auth_service.dart';

/// Local Data Adapter replacing the remote REST API.
/// All queries run offline directly inside the mobile app's embedded SQLite database.
class ApiService {
  static final DatabaseService _db = DatabaseService.instance;

  // =========================
  // CONNECTION STATUS
  // =========================
  static Future<String> testConnection() async {
    await _db.database;
    return 'Offline Local Database is active and ready!';
  }

  // =========================
  // DASHBOARD
  // =========================
  static Future<Map<String, dynamic>> getDashboard() async {
    return await _db.getDashboard();
  }

  // =========================
  // STUDENTS
  // =========================
  static Future<List<dynamic>> getStudents() async {
    return await _db.getStudents();
  }

  static Future<Map<String, dynamic>> addStudent({
    required int roomId,
    required String name,
    required String phone,
    required String joinDate,
  }) async {
    return await _db.addStudent(
      roomId: roomId,
      name: name,
      phone: phone,
      joinDate: joinDate,
    );
  }

  static Future<void> deleteStudent(int id) async {
    await _db.deleteStudent(id);
  }

  // =========================
  // ROOMS
  // =========================
  static Future<List<dynamic>> getRooms() async {
    return await _db.getRooms();
  }

  static Future<Map<String, dynamic>> addRoom({
    required String roomName,
    required int capacity,
    required double monthlyFee,
  }) async {
    return await _db.addRoom(
      roomName: roomName,
      capacity: capacity,
      monthlyFee: monthlyFee,
    );
  }

  static Future<void> updateRoom({
    required int id,
    required String roomName,
    required int capacity,
    required double monthlyFee,
  }) async {
    await _db.updateRoom(
      id: id,
      roomName: roomName,
      capacity: capacity,
      monthlyFee: monthlyFee,
    );
  }

  static Future<void> deleteRoom(int id) async {
    await _db.deleteRoom(id);
  }

  // =========================
  // MONTHLY BILLS
  // =========================
  static Future<List<dynamic>> getMonthlyBills({String? month, int? studentId}) async {
    return await _db.getMonthlyBills(month: month, studentId: studentId);
  }

  static Future<Map<String, dynamic>> generateMonthlyBills({
    required String month,
    String? dueDate,
  }) async {
    return await _db.generateMonthlyBills(month: month, dueDate: dueDate);
  }

  // =========================
  // UTILITY BILLS
  // =========================
  static Future<Map<String, dynamic>> addUtilityBill({
    required String month,
    required String type,
    required double amount,
    String? startDate,
    String? endDate,
  }) async {
    return await _db.addUtilityBill(
      month: month,
      type: type,
      amount: amount,
      startDate: startDate,
      endDate: endDate,
    );
  }

  static Future<List<Map<String, dynamic>>> getUtilityBills({
    String? month,
    String? type,
  }) async {
    return await _db.getUtilityBills(month: month, type: type);
  }

  // =========================
  // PAYMENTS
  // =========================
  static Future<Map<String, dynamic>> addPayment({
    required int monthlyBillId,
    required double amount,
    required String paidDate,
    String? paymentMethod,
    String? note,
  }) async {
    return await _db.addPayment(
      monthlyBillId: monthlyBillId,
      amount: amount,
      paidDate: paidDate,
      paymentMethod: paymentMethod,
      note: note,
    );
  }

  // =========================
  // SETTINGS & BACKUP
  // =========================
  static Future<Map<String, String>> getSettings() async {
    return await _db.getSettings();
  }

  static Future<void> updateSetting(String key, String value) async {
    await _db.updateSetting(key, value);
  }

  static Future<String> exportBackupJson() async {
    return await _db.exportBackupJson();
  }

  static Future<void> importBackupJson(String jsonString) async {
    await _db.importBackupJson(jsonString);
  }

  // =========================
  // AUTH / USER MANAGEMENT
  // =========================
  static Future<List<AppUser>> getPendingBoarders() async {
    return await _db.getPendingBoarders();
  }

  static Future<List<AppUser>> getAllBoarders() async {
    return await _db.getAllBoarders();
  }

  static Future<List<AppUser>> getAllStaff() async {
    return await _db.getAllStaff();
  }

  static Future<void> approveAndLinkBoarder({
    required int userId,
    required int studentId,
  }) async {
    await _db.approveAndLinkBoarder(userId: userId, studentId: studentId);
  }

  static Future<void> rejectBoarder(int userId) async {
    await _db.rejectBoarder(userId);
  }

  static Future<void> createStaffAccount({
    required String name,
    required String email,
    required String phone,
    required String pin,
    required UserRole role,
    required List<StaffPermission> permissions,
  }) async {
    await AuthService.instance.createStaffAccount(
      name: name,
      email: email,
      phone: phone,
      pin: pin,
      role: role,
      permissions: permissions,
    );
  }

  // =========================
  // NOTIFICATIONS
  // =========================
  static Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    return await _db.getNotifications(userId);
  }

  static Future<int> getUnreadNotificationCount(int userId) async {
    return await _db.getUnreadNotificationCount(userId);
  }

  static Future<void> markNotificationsRead(int userId) async {
    await _db.markNotificationsRead(userId);
  }
}