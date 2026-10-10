import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'utility_date_helper.dart';
import 'models/user_model.dart';
import 'auth/auth_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'boarding_manager.db');

    return await openDatabase(
      dbPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.update('rooms', {'capacity': 2, 'monthly_fee': 12000.0},
          where: 'room_name = ?', whereArgs: ['Room 1']);
      await db.update('rooms', {'capacity': 2, 'monthly_fee': 12000.0},
          where: 'room_name = ?', whereArgs: ['Room 2']);
      await db.update('rooms', {'capacity': 1, 'monthly_fee': 13000.0},
          where: 'room_name = ?', whereArgs: ['Room 3']);
    }
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE utility_bills ADD COLUMN start_date TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE utility_bills ADD COLUMN end_date TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE monthly_bills ADD COLUMN total_electricity REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE monthly_bills ADD COLUMN total_water REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE monthly_bills ADD COLUMN student_count INTEGER DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE monthly_bills ADD COLUMN electricity_period TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE monthly_bills ADD COLUMN water_period TEXT'); } catch (_) {}
    }
    if (oldVersion < 4) {
      // Add users, staff_permissions tables (non-destructive)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          name              TEXT NOT NULL,
          email             TEXT UNIQUE,
          phone             TEXT,
          role              TEXT NOT NULL DEFAULT 'boarder',
          status            TEXT NOT NULL DEFAULT 'active',
          password_hash     TEXT NOT NULL DEFAULT '',
          password_salt     TEXT NOT NULL DEFAULT '',
          linked_student_id INTEGER,
          created_at        TEXT NOT NULL,
          FOREIGN KEY (linked_student_id) REFERENCES students(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_permissions (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id    INTEGER NOT NULL,
          permission TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      // Add notifications table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id    INTEGER NOT NULL,
          title      TEXT NOT NULL,
          body       TEXT NOT NULL,
          type       TEXT,
          is_read    INTEGER NOT NULL DEFAULT 0,
          related_id INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      // Seed default super_admin account (PIN: 1234)
      await _seedDefaultAdmin(db);
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 2. Rooms
    await db.execute('''
      CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_name TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 1,
        monthly_fee REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Students (boarders linked to rooms)
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        join_date TEXT NOT NULL,
        leave_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
      )
    ''');

    // 4. Users (auth accounts)
    await db.execute('''
      CREATE TABLE users (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT NOT NULL,
        email             TEXT UNIQUE,
        phone             TEXT,
        role              TEXT NOT NULL DEFAULT 'boarder',
        status            TEXT NOT NULL DEFAULT 'active',
        password_hash     TEXT NOT NULL DEFAULT '',
        password_salt     TEXT NOT NULL DEFAULT '',
        linked_student_id INTEGER,
        created_at        TEXT NOT NULL,
        FOREIGN KEY (linked_student_id) REFERENCES students(id) ON DELETE SET NULL
      )
    ''');

    // 5. Staff permissions
    await db.execute('''
      CREATE TABLE staff_permissions (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        permission TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 6. Utility Bills
    await db.execute('''
      CREATE TABLE utility_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        start_date TEXT,
        end_date TEXT,
        entered_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 7. Monthly Bills
    await db.execute('''
      CREATE TABLE monthly_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        boarding_fee REAL NOT NULL,
        electricity REAL NOT NULL DEFAULT 0.0,
        water REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'unpaid',
        total_electricity REAL DEFAULT 0.0,
        total_water REAL DEFAULT 0.0,
        student_count INTEGER DEFAULT 1,
        electricity_period TEXT,
        water_period TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');

    // 8. Payments
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monthly_bill_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        paid_date TEXT NOT NULL,
        payment_method TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (monthly_bill_id) REFERENCES monthly_bills(id) ON DELETE CASCADE
      )
    ''');

    // 9. Notifications
    await db.execute('''
      CREATE TABLE notifications (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        title      TEXT NOT NULL,
        body       TEXT NOT NULL,
        type       TEXT,
        is_read    INTEGER NOT NULL DEFAULT 0,
        related_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Seed default settings
    await db.insert('settings', {'key': 'boarding_house_name', 'value': 'Sunrise Boarding House'});
    await db.insert('settings', {'key': 'currency', 'value': 'LKR'});

    // Seed initial rooms
    final now = DateTime.now().toIso8601String();
    await db.insert('rooms', {'room_name': 'Room 1', 'capacity': 2, 'monthly_fee': 12000.0, 'status': 'active', 'created_at': now});
    await db.insert('rooms', {'room_name': 'Room 2', 'capacity': 2, 'monthly_fee': 12000.0, 'status': 'active', 'created_at': now});
    await db.insert('rooms', {'room_name': 'Room 3', 'capacity': 1, 'monthly_fee': 13000.0, 'status': 'active', 'created_at': now});

    // Seed default admin
    await _seedDefaultAdmin(db);
  }

  Future<void> _seedDefaultAdmin(Database db) async {
    // Only seed if no admin exists yet
    final existing = await db.query('users', where: 'role = ?', whereArgs: ['super_admin'], limit: 1);
    if (existing.isNotEmpty) return;

    final salt = AuthService.generateSalt();
    final hash = AuthService.hashPin('123456', salt);
    final now  = DateTime.now().toIso8601String();

    await db.insert('users', {
      'name':          'Super Admin',
      'email':         'admin@boarding.local',
      'phone':         '',
      'role':          'super_admin',
      'status':        'active',
      'password_hash': hash,
      'password_salt': salt,
      'created_at':    now,
    });
  }

  // =========================================================================
  // USER / AUTH
  // =========================================================================

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db   = await database;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<AppUser?> getUserById(int id) async {
    final db   = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final permissions = await getStaffPermissions(id);
    return AppUser.fromMap(Map<String, dynamic>.from(rows.first), permissions: permissions);
  }

  Future<int> createUser({
    required String name,
    required String? email,
    required String? phone,
    required UserRole role,
    required BoarderStatus status,
    required String passwordHash,
    required String passwordSalt,
    int? linkedStudentId,
  }) async {
    final db  = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('users', {
      'name':              name,
      'email':             email,
      'phone':             phone,
      'role':              role.dbValue,
      'status':            status.dbValue,
      'password_hash':     passwordHash,
      'password_salt':     passwordSalt,
      'linked_student_id': linkedStudentId,
      'created_at':        now,
    });
  }

  Future<List<StaffPermission>> getStaffPermissions(int userId) async {
    final db   = await database;
    final rows = await db.query('staff_permissions', where: 'user_id = ?', whereArgs: [userId]);
    return rows
        .map((r) => StaffPermission.fromDb(r['permission'] as String? ?? ''))
        .whereType<StaffPermission>()
        .toList();
  }

  Future<void> setStaffPermissions(int userId, List<StaffPermission> permissions) async {
    final db = await database;
    await db.delete('staff_permissions', where: 'user_id = ?', whereArgs: [userId]);
    for (final p in permissions) {
      await db.insert('staff_permissions', {'user_id': userId, 'permission': p.dbValue});
    }
  }

  Future<List<AppUser>> getPendingBoarders() async {
    final db   = await database;
    final rows = await db.query(
      'users',
      where: 'role = ? AND status = ?',
      whereArgs: ['boarder', 'pending_approval'],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => AppUser.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<AppUser>> getAllBoarders() async {
    final db   = await database;
    final rows = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['boarder'],
      orderBy: 'name ASC',
    );
    return rows.map((r) => AppUser.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<AppUser>> getAllStaff() async {
    final db   = await database;
    final rows = await db.query(
      'users',
      where: "role IN ('manager','staff','super_admin')",
      orderBy: 'role ASC, name ASC',
    );
    final List<AppUser> result = [];
    for (final r in rows) {
      final userId      = r['id'] as int;
      final permissions = await getStaffPermissions(userId);
      result.add(AppUser.fromMap(Map<String, dynamic>.from(r), permissions: permissions));
    }
    return result;
  }

  Future<void> approveAndLinkBoarder({
    required int userId,
    required int studentId,
  }) async {
    final db = await database;
    await db.update(
      'users',
      {'status': 'active', 'linked_student_id': studentId},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> rejectBoarder(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'status': 'inactive'},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> changeUserPin({
    required int userId,
    required String currentPin,
    required String newPin,
    required String Function(String pin, String salt) hashFn,
  }) async {
    final db  = await database;
    final row = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (row.isEmpty) throw Exception('User not found.');

    final salt    = row.first['password_salt'] as String? ?? '';
    final stored  = row.first['password_hash'] as String? ?? '';
    final entered = hashFn(currentPin, salt);

    if (entered != stored) throw Exception('Current PIN is incorrect.');

    final newSalt = AuthService.generateSalt();
    final newHash = hashFn(newPin, newSalt);

    await db.update(
      'users',
      {'password_hash': newHash, 'password_salt': newSalt},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // =========================================================================
  // NOTIFICATIONS
  // =========================================================================

  Future<void> createNotification({
    required int userId,
    required String title,
    required String body,
    String? type,
    int? relatedId,
  }) async {
    final db  = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('notifications', {
      'user_id':    userId,
      'title':      title,
      'body':       body,
      'type':       type,
      'is_read':    0,
      'related_id': relatedId,
      'created_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final db = await database;
    final rows = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 50,
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<int> getUnreadNotificationCount(int userId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM notifications WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return (res.first['cnt'] as int?) ?? 0;
  }

  Future<void> markNotificationsRead(int userId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
  }

  // =========================================================================
  // DASHBOARD
  // =========================================================================
  Future<Map<String, dynamic>> getDashboard() async {
    final db = await database;

    final studentCountRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM students WHERE status = 'active'",
    );
    final int studentCount = (studentCountRes.first['count'] as int?) ?? 0;

    final roomCountRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM rooms WHERE status = 'active'",
    );
    final int roomCount = (roomCountRes.first['count'] as int?) ?? 0;

    final paidRes = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM monthly_bills WHERE status = 'paid'",
    );
    final double paid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final pendingRes = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM monthly_bills WHERE status = 'unpaid'",
    );
    final double pending = (pendingRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final pendingBoardersRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM users WHERE role = 'boarder' AND status = 'pending_approval'",
    );
    final int pendingBoarders = (pendingBoardersRes.first['count'] as int?) ?? 0;

    return {
      'students': studentCount,
      'rooms': roomCount,
      'paid': paid,
      'pending': pending,
      'pending_boarders': pendingBoarders,
    };
  }

  // =========================================================================
  // ROOMS
  // =========================================================================
  Future<List<Map<String, dynamic>>> getRooms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, 
             COUNT(CASE WHEN s.status = 'active' THEN s.id ELSE NULL END) as students_count
      FROM rooms r
      LEFT JOIN students s ON s.room_id = r.id
      WHERE r.status = 'active'
      GROUP BY r.id
      ORDER BY r.id ASC
    ''');

    return maps.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> addRoom({
    required String roomName,
    required int capacity,
    required double monthlyFee,
  }) async {
    final db  = await database;
    final now = DateTime.now().toIso8601String();
    final id  = await db.insert('rooms', {
      'room_name':   roomName,
      'capacity':    capacity,
      'monthly_fee': monthlyFee,
      'status':      'active',
      'created_at':  now,
    });

    return {
      'message':     'Room added successfully',
      'id':          id,
      'room_name':   roomName,
      'capacity':    capacity,
      'monthly_fee': monthlyFee,
    };
  }

  Future<void> updateRoom({
    required int id,
    required String roomName,
    required int capacity,
    required double monthlyFee,
  }) async {
    final db = await database;
    await db.update(
      'rooms',
      {'room_name': roomName, 'capacity': capacity, 'monthly_fee': monthlyFee},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRoom(int id) async {
    final db       = await database;
    final countRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM students WHERE room_id = ? AND status = 'active'",
      [id],
    );
    final count = (countRes.first['count'] as int?) ?? 0;
    if (count > 0) {
      throw Exception('Cannot delete room because it currently has active students.');
    }
    await db.update('rooms', {'status': 'inactive'}, where: 'id = ?', whereArgs: [id]);
  }

  // =========================================================================
  // STUDENTS
  // =========================================================================
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db   = await database;
    final rows = await db.rawQuery('''
      SELECT s.*, r.room_name, r.capacity, r.monthly_fee
      FROM students s
      LEFT JOIN rooms r ON s.room_id = r.id
      WHERE s.status = 'active'
      ORDER BY s.id DESC
    ''');

    return rows.map((row) => {
      'id':        row['id'],
      'room_id':   row['room_id'],
      'name':      row['name'],
      'phone':     row['phone'],
      'join_date': row['join_date'],
      'leave_date':row['leave_date'],
      'status':    row['status'],
      'room': {
        'id':          row['room_id'],
        'room_name':   row['room_name'] ?? 'Unassigned',
        'capacity':    row['capacity'] ?? 0,
        'monthly_fee': row['monthly_fee'] ?? 0.0,
      }
    }).toList();
  }

  Future<Map<String, dynamic>> addStudent({
    required int roomId,
    required String name,
    required String phone,
    required String joinDate,
  }) async {
    final db  = await database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('students', {
      'room_id':    roomId,
      'name':       name,
      'phone':      phone,
      'join_date':  joinDate,
      'status':     'active',
      'created_at': now,
    });

    return {
      'message': 'Student added successfully',
      'student': {'id': id, 'room_id': roomId, 'name': name, 'phone': phone, 'join_date': joinDate, 'status': 'active'},
    };
  }

  Future<void> deleteStudent(int id) async {
    final db = await database;
    await db.update(
      'students',
      {'status': 'inactive', 'leave_date': DateTime.now().toIso8601String().split('T')[0]},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================================================================
  // UTILITIES
  // =========================================================================
  Future<Map<String, dynamic>> addUtilityBill({
    required String month,
    required String type,
    required double amount,
    String? startDate,
    String? endDate,
  }) async {
    final db       = await database;
    final now      = DateTime.now().toIso8601String();
    final existing = await db.query(
      'utility_bills',
      where: 'month = ? AND type = ?',
      whereArgs: [month, type],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'utility_bills',
        {'amount': amount, 'start_date': startDate, 'end_date': endDate, 'entered_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('utility_bills', {
        'month':      month,
        'type':       type,
        'amount':     amount,
        'start_date': startDate,
        'end_date':   endDate,
        'entered_at': now,
        'created_at': now,
      });
    }
    return {'message': 'Utility bill saved successfully.'};
  }

  Future<List<Map<String, dynamic>>> getUtilityBills({String? month, String? type}) async {
    final db   = await database;
    String query = 'SELECT * FROM utility_bills WHERE 1=1';
    List<dynamic> args = [];

    if (month != null && month.isNotEmpty) { query += ' AND month = ?'; args.add(month); }
    if (type  != null && type.isNotEmpty)  { query += ' AND type = ?';  args.add(type);  }
    query += ' ORDER BY id DESC';

    final rows = await db.rawQuery(query, args);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // =========================================================================
  // MONTHLY BILLS
  // =========================================================================
  Future<List<Map<String, dynamic>>> getMonthlyBills({String? month, int? studentId}) async {
    final db   = await database;
    String query = '''
      SELECT b.*, 
             s.name as student_name, 
             s.phone as student_phone, 
             r.room_name
      FROM monthly_bills b
      JOIN students s ON b.student_id = s.id
      LEFT JOIN rooms r ON s.room_id = r.id
    ''';
    List<dynamic> args = [];
    List<String> conditions = [];

    if (month     != null && month.isNotEmpty)  conditions.add('b.month = ?');
    if (studentId != null)                       conditions.add('b.student_id = ?');

    if (month     != null && month.isNotEmpty)  args.add(month);
    if (studentId != null)                       args.add(studentId);

    if (conditions.isNotEmpty) query += ' WHERE ${conditions.join(' AND ')}';
    query += ' ORDER BY b.id DESC';

    final rows = await db.rawQuery(query, args);

    return rows.map((row) {
      final billMonth   = (row['month'] as String?) ?? '2026-09';
      final defaultElec = UtilityDateHelper.defaultElectricityPeriod(billMonth);
      final defaultWater= UtilityDateHelper.defaultWaterPeriod(billMonth);
      final studentCnt  = (row['student_count'] as num?)?.toInt() ?? 1;

      double totalElec = (row['total_electricity'] as num?)?.toDouble() ?? 0.0;
      if (totalElec == 0.0 && row['electricity'] != null) {
        totalElec = (row['electricity'] as num).toDouble() * studentCnt;
      }
      double totalWtr = (row['total_water'] as num?)?.toDouble() ?? 0.0;
      if (totalWtr == 0.0 && row['water'] != null) {
        totalWtr = (row['water'] as num).toDouble() * studentCnt;
      }

      final elecPeriod = (row['electricity_period'] as String?)?.isNotEmpty == true
          ? (row['electricity_period'] as String)
          : '${defaultElec['start']} to ${defaultElec['end']}';

      final waterPeriod = (row['water_period'] as String?)?.isNotEmpty == true
          ? (row['water_period'] as String)
          : '${defaultWater['start']} to ${defaultWater['end']}';

      return {
        'id':                row['id'],
        'student_id':        row['student_id'],
        'month':             row['month'],
        'boarding_fee':      row['boarding_fee'],
        'electricity':       row['electricity'],
        'water':             row['water'],
        'total':             row['total'],
        'due_date':          row['due_date'],
        'status':            row['status'],
        'total_electricity': totalElec,
        'total_water':       totalWtr,
        'student_count':     studentCnt,
        'electricity_period':elecPeriod,
        'water_period':      waterPeriod,
        'student': {
          'id':    row['student_id'],
          'name':  row['student_name'] ?? 'Unknown Student',
          'phone': row['student_phone'] ?? '',
          'room':  {'room_name': row['room_name'] ?? 'No Room'},
        }
      };
    }).toList();
  }

  Future<Map<String, dynamic>> generateMonthlyBills({
    required String month,
    String? dueDate,
  }) async {
    final db = await database;

    final elecRes = await db.rawQuery(
      "SELECT amount, start_date, end_date FROM utility_bills WHERE month = ? AND type = 'electricity' ORDER BY id DESC LIMIT 1",
      [month],
    );
    final double electricity = elecRes.isNotEmpty ? ((elecRes.first['amount'] as num?)?.toDouble() ?? 0.0) : 0.0;
    String? elecStart = elecRes.isNotEmpty ? (elecRes.first['start_date'] as String?) : null;
    String? elecEnd   = elecRes.isNotEmpty ? (elecRes.first['end_date']   as String?) : null;
    if (elecStart == null || elecStart.isEmpty || elecEnd == null || elecEnd.isEmpty) {
      final defaultElec = UtilityDateHelper.defaultElectricityPeriod(month);
      elecStart = defaultElec['start'];
      elecEnd   = defaultElec['end'];
    }
    final String elecPeriod = '$elecStart to $elecEnd';

    final waterRes = await db.rawQuery(
      "SELECT amount, start_date, end_date FROM utility_bills WHERE month = ? AND type = 'water' ORDER BY id DESC LIMIT 1",
      [month],
    );
    final double water = waterRes.isNotEmpty ? ((waterRes.first['amount'] as num?)?.toDouble() ?? 0.0) : 0.0;
    String? waterStart = waterRes.isNotEmpty ? (waterRes.first['start_date'] as String?) : null;
    String? waterEnd   = waterRes.isNotEmpty ? (waterRes.first['end_date']   as String?) : null;
    if (waterStart == null || waterStart.isEmpty || waterEnd == null || waterEnd.isEmpty) {
      final defaultWater = UtilityDateHelper.defaultWaterPeriod(month);
      waterStart = defaultWater['start'];
      waterEnd   = defaultWater['end'];
    }
    final String waterPeriod = '$waterStart to $waterEnd';

    final students = await db.rawQuery('''
      SELECT s.id as student_id, r.monthly_fee
      FROM students s
      JOIN rooms r ON s.room_id = r.id
      WHERE s.status = 'active'
    ''');

    if (students.isEmpty) throw Exception('No active students found to generate bills.');

    final int studentCount    = students.length;
    final double elecPerStudent  = electricity / studentCount;
    final double waterPerStudent = water / studentCount;
    final now = DateTime.now().toIso8601String();
    List<Map<String, dynamic>> createdBills = [];

    await db.transaction((txn) async {
      for (final student in students) {
        final int    studentId   = student['student_id'] as int;
        final double boardingFee = (student['monthly_fee'] as num?)?.toDouble() ?? 0.0;
        final double total       = boardingFee + elecPerStudent + waterPerStudent;

        final existing = await txn.query(
          'monthly_bills',
          where: 'student_id = ? AND month = ?',
          whereArgs: [studentId, month],
        );

        if (existing.isNotEmpty) {
          final int    billId        = existing.first['id'] as int;
          final String currentStatus = existing.first['status'] as String? ?? 'unpaid';

          await txn.update(
            'monthly_bills',
            {
              'boarding_fee':       boardingFee,
              'electricity':        elecPerStudent,
              'water':              waterPerStudent,
              'total':              total,
              'due_date':           dueDate,
              'status':             currentStatus,
              'total_electricity':  electricity,
              'total_water':        water,
              'student_count':      studentCount,
              'electricity_period': elecPeriod,
              'water_period':       waterPeriod,
            },
            where: 'id = ?',
            whereArgs: [billId],
          );
          createdBills.add({'id': billId, 'student_id': studentId, 'month': month, 'total': total});
        } else {
          final billId = await txn.insert('monthly_bills', {
            'student_id':         studentId,
            'month':              month,
            'boarding_fee':       boardingFee,
            'electricity':        elecPerStudent,
            'water':              waterPerStudent,
            'total':              total,
            'due_date':           dueDate,
            'status':             'unpaid',
            'total_electricity':  electricity,
            'total_water':        water,
            'student_count':      studentCount,
            'electricity_period': elecPeriod,
            'water_period':       waterPeriod,
            'created_at':         now,
          });
          createdBills.add({'id': billId, 'student_id': studentId, 'month': month, 'total': total});
        }
      }
    });

    return {'message': 'Monthly bills generated successfully.', 'bills': createdBills};
  }

  // =========================================================================
  // PAYMENTS
  // =========================================================================
  Future<Map<String, dynamic>> addPayment({
    required int monthlyBillId,
    required double amount,
    required String paidDate,
    String? paymentMethod,
    String? note,
  }) async {
    final db  = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('payments', {
        'monthly_bill_id': monthlyBillId,
        'amount':          amount,
        'paid_date':       paidDate,
        'payment_method':  paymentMethod ?? 'Cash',
        'note':            note,
        'created_at':      now,
      });
      await txn.update(
        'monthly_bills',
        {'status': 'paid'},
        where: 'id = ?',
        whereArgs: [monthlyBillId],
      );
    });

    return {'message': 'Payment recorded successfully.'};
  }

  // =========================================================================
  // SETTINGS
  // =========================================================================
  Future<Map<String, String>> getSettings() async {
    final db   = await database;
    final rows = await db.query('settings');
    final Map<String, String> settings = {};
    for (final row in rows) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =========================================================================
  // BACKUP & RESTORE
  // =========================================================================
  Future<String> exportBackupJson() async {
    final db = await database;
    final backup = {
      'version':      2,
      'exported_at':  DateTime.now().toIso8601String(),
      'settings':     await db.query('settings'),
      'rooms':        await db.query('rooms'),
      'students':     await db.query('students'),
      'utility_bills':await db.query('utility_bills'),
      'monthly_bills':await db.query('monthly_bills'),
      'payments':     await db.query('payments'),
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<void> importBackupJson(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('monthly_bills');
      await txn.delete('utility_bills');
      await txn.delete('students');
      await txn.delete('rooms');
      await txn.delete('settings');

      for (final table in ['settings','rooms','students','utility_bills','monthly_bills','payments']) {
        if (data[table] != null) {
          for (final item in (data[table] as List)) {
            await txn.insert(table, Map<String, dynamic>.from(item));
          }
        }
      }
    });
  }
}
