import 'package:flutter/material.dart';
import 'auth/auth_service.dart';
import 'models/user_model.dart';

// Manager pages (original)
import 'rooms_page.dart';
import 'students_page.dart';
import 'monthly_bills_page.dart';
import 'utilities_page.dart';
import 'settings_page.dart';

// Auth pages
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/pending_approval_page.dart';

// Manager-specific pages
import 'pages/manager/pending_boarders_page.dart';
import 'pages/manager/staff_management_page.dart';

// Boarder pages
import 'pages/boarder/boarder_dashboard_page.dart';

import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore session before rendering the first frame
  await AuthService.instance.restoreSession();
  runApp(const BoardingManagerApp());
}

class BoardingManagerApp extends StatelessWidget {
  const BoardingManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Boarding Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Route-based navigation
      initialRoute: '/',
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

// ---------------------------------------------------------------------------
// Role-based router
// ---------------------------------------------------------------------------

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final user = AuthService.instance.currentUser;

    switch (settings.name) {
      case '/login':
        return _fade(const LoginPage());

      case '/signup':
        return _slide(const SignupPage());

      case '/pending-approval':
        return _fade(const PendingApprovalPage());

      case '/notifications':
        if (user == null) return _fade(const LoginPage());
        return _slide(const NotificationsPage());

      case '/my-bills':
        if (user == null) return _fade(const LoginPage());
        return _slide(const BoarderBillsPage());

      case '/manager/pending-boarders':
        if (user == null) return _fade(const LoginPage());
        return _slide(const PendingBoardersPage());

      case '/manager/staff':
        if (user == null) return _fade(const LoginPage());
        return _slide(const StaffManagementPage());

      case '/':
      default:
        return _buildHomeRoute(user);
    }
  }

  static Route<dynamic> _buildHomeRoute(AppUser? user) {
    if (user == null) {
      // Not logged in → show login
      return _fade(const LoginPage());
    }

    switch (user.status) {
      case BoarderStatus.pendingApproval:
        // Boarder waiting for manager approval
        return _fade(const PendingApprovalPage());

      case BoarderStatus.inactive:
        // Deactivated account — log them out and send to login
        AuthService.instance.clearSession();
        return _fade(const LoginPage());

      case BoarderStatus.active:
        if (user.role == UserRole.boarder) {
          return _fade(const BoarderDashboardPage());
        } else {
          // Manager / Staff / Super-admin
          return _fade(const ManagerShell());
        }
    }
  }

  static MaterialPageRoute<dynamic> _fade(Widget page) =>
      MaterialPageRoute(builder: (_) => page);

  static MaterialPageRoute<dynamic> _slide(Widget page) =>
      MaterialPageRoute(builder: (_) => page);
}

// ---------------------------------------------------------------------------
// Manager Shell — original dashboard with auth additions
// ---------------------------------------------------------------------------

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _currentTabIndex = 0;

  int    students        = 0;
  int    rooms           = 0;
  double paid            = 0;
  double pending         = 0;
  int    pendingBoarders = 0;
  String currency        = 'LKR';
  String houseName       = 'Sunrise Boarding House';

  bool    isLoading    = true;
  String? errorMessage;

  final AppUser? _currentUser = AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final data     = await ApiService.getDashboard();
      final settings = await ApiService.getSettings();

      if (!mounted) return;

      setState(() {
        students        = int.tryParse(data['students'].toString()) ?? 0;
        rooms           = int.tryParse(data['rooms'].toString()) ?? 0;
        paid            = double.tryParse(data['paid'].toString()) ?? 0;
        pending         = double.tryParse(data['pending'].toString()) ?? 0;
        pendingBoarders = int.tryParse(data['pending_boarders'].toString()) ?? 0;
        currency        = settings['currency'] ?? 'LKR';
        houseName       = settings['boarding_house_name'] ?? 'Sunrise Boarding House';
        isLoading       = false;
        errorMessage    = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { errorMessage = e.toString(); isLoading = false; });
    }
  }

  String formatAmount(double amount) => '$currency ${amount.toStringAsFixed(0)}';

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onBottomNavTapped(int index) async {
    if (index == 0) return;
    if (index == 1) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomsPage()));
    } else if (index == 2) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsPage()));
    } else if (index == 3) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyBillsPage()));
    }
    if (mounted) { setState(() => _currentTabIndex = 0); loadDashboard(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(houseName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Pending boarders badge (manager/admin only)
          if ((_currentUser?.role.isManagerOrAbove ?? false) && pendingBoarders > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add_alt_outlined),
                  tooltip: 'Pending Approvals',
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/manager/pending-boarders');
                    loadDashboard();
                  },
                ),
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$pendingBoarders',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'pending') {
                if (!context.mounted) return;
                await Navigator.pushNamed(context, '/manager/pending-boarders');
                loadDashboard();
              }
              if (action == 'staff') {
                if (!context.mounted) return;
                await Navigator.pushNamed(context, '/manager/staff');
              }
              if (action == 'settings') {
                if (!context.mounted) return;
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                loadDashboard();
              }
              if (action == 'logout') { await _logout(); }
            },
            itemBuilder: (_) => [
              if (_currentUser?.role.isManagerOrAbove ?? false) ...[
                const PopupMenuItem(value: 'pending',  child: _MenuItem(Icons.person_add_alt,  'Pending Approvals')),
                const PopupMenuItem(value: 'staff',    child: _MenuItem(Icons.group,            'Staff Management')),
              ],
              const PopupMenuItem(value: 'settings', child: _MenuItem(Icons.settings,          'Settings & Backup')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: _MenuItem(Icons.logout, 'Sign Out',
                  color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20),
                  child: Text('Error loading dashboard:\n$errorMessage', textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Dashboard',
                                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('Manage your boarding house easily',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ],
                            ),
                            _RoleBadge(_currentUser?.role),
                          ],
                        ),

                        // Pending boarders alert banner
                        if (pendingBoarders > 0) ...[
                          const SizedBox(height: 14),
                          _PendingBanner(
                            count: pendingBoarders,
                            onTap: () async {
                              await Navigator.pushNamed(context, '/manager/pending-boarders');
                              loadDashboard();
                            },
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Statistics
                        Row(children: [
                          Expanded(child: _statCard('Boarders', students.toString(), Icons.people, Colors.blue)),
                          const SizedBox(width: 12),
                          Expanded(child: _statCard('Rooms', rooms.toString(), Icons.meeting_room, Colors.indigo)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _statCard('Collected', formatAmount(paid), Icons.check_circle, Colors.green)),
                          const SizedBox(width: 12),
                          Expanded(child: _statCard('Pending', formatAmount(pending), Icons.pending_actions, Colors.orange)),
                        ]),

                        const SizedBox(height: 28),

                        const Text('Quick Actions',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        _actionTile(
                          icon: Icons.people, iconColor: Colors.blue,
                          title: 'Students / Boarders', subtitle: 'View and manage boarding students',
                          onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsPage())); loadDashboard(); },
                        ),
                        _actionTile(
                          icon: Icons.receipt_long, iconColor: Colors.purple,
                          title: 'Monthly Bills', subtitle: 'Generate bills, record payments & share PDFs',
                          onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyBillsPage())); loadDashboard(); },
                        ),
                        _actionTile(
                          icon: Icons.bolt, iconColor: Colors.amber.shade800,
                          title: 'Utilities', subtitle: 'Enter monthly electricity and water bills',
                          onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const UtilitiesPage())); loadDashboard(); },
                        ),
                        _actionTile(
                          icon: Icons.meeting_room, iconColor: Colors.indigo,
                          title: 'Rooms', subtitle: 'Manage room capacities and monthly fees',
                          onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomsPage())); loadDashboard(); },
                        ),
                        if (_currentUser?.role.isManagerOrAbove ?? false) ...[
                          _actionTile(
                            icon: Icons.person_add_alt, iconColor: Colors.orange,
                            title: 'Pending Approvals',
                            subtitle: pendingBoarders > 0 ? '$pendingBoarders boarders waiting for approval' : 'Review boarder signup requests',
                            badge: pendingBoarders > 0 ? '$pendingBoarders' : null,
                            onTap: () async { await Navigator.pushNamed(context, '/manager/pending-boarders'); loadDashboard(); },
                          ),
                          _actionTile(
                            icon: Icons.group, iconColor: Colors.teal,
                            title: 'Staff Management', subtitle: 'Create and manage staff accounts',
                            onTap: () => Navigator.pushNamed(context, '/manager/staff'),
                          ),
                        ],
                        _actionTile(
                          icon: Icons.cloud_download_outlined, iconColor: Colors.teal,
                          title: 'Backup & Settings', subtitle: 'Export data backup or configure house details',
                          onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())); loadDashboard(); },
                        ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: _onBottomNavTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.meeting_room_outlined), selectedIcon: Icon(Icons.meeting_room), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Bills'),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 20, color: color)),
            ]),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required VoidCallback onTap, String? badge,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: badge != null
            ? Stack(children: [
                CircleAvatar(backgroundColor: iconColor.withValues(alpha: 0.12), child: Icon(icon, color: iconColor)),
                Positioned(right: 0, top: 0, child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                )),
              ])
            : CircleAvatar(backgroundColor: iconColor.withValues(alpha: 0.12), child: Icon(icon, color: iconColor)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  final UserRole? role;
  const _RoleBadge(this.role);

  @override
  Widget build(BuildContext context) {
    if (role == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_user, size: 13, color: colors.primary),
        const SizedBox(width: 4),
        Text(role!.displayName,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary)),
      ]),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.person_add_alt, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(
              '$count boarder${count == 1 ? '' : 's'} waiting for approval',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            )),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
          ]),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuItem(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Notifications page (simple, works for both boarders and managers)
// ---------------------------------------------------------------------------

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getNotifications(user.id);
      await ApiService.markNotificationsRead(user.id);
      if (!mounted) return;
      setState(() { _notifications = list; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications yet.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _notifications.length,
                  itemBuilder: (ctx, i) {
                    final n       = _notifications[i];
                    final isRead  = (n['is_read'] as int?) == 1;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: const Icon(Icons.notifications, color: Colors.indigo, size: 20),
                        ),
                        title: Text(n['title'] as String? ?? '',
                            style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['body'] as String? ?? ''),
                            Text(n['created_at'] as String? ?? '',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Boarder bills list page
// ---------------------------------------------------------------------------

class BoarderBillsPage extends StatefulWidget {
  const BoarderBillsPage({super.key});

  @override
  State<BoarderBillsPage> createState() => _BoarderBillsPageState();
}

class _BoarderBillsPageState extends State<BoarderBillsPage> {
  List<dynamic> _bills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final bills = await ApiService.getMonthlyBills(studentId: user.linkedStudentId);
      if (!mounted) return;
      setState(() { _bills = bills; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bills.isEmpty
              ? const Center(child: Text('No bills found.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length,
                  itemBuilder: (ctx, i) {
                    final bill   = _bills[i];
                    final status = bill['status'] as String? ?? 'unpaid';
                    final total  = (bill['total'] as num?)?.toDouble() ?? 0.0;
                    final month  = bill['month'] as String? ?? '';
                    Color color;
                    String label;
                    switch (status) {
                      case 'paid':              color = Colors.green;  label = 'Paid';    break;
                      case 'pending_approval':  color = Colors.blue;   label = 'Pending'; break;
                      default:                  color = Colors.orange; label = 'Unpaid';
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(Icons.receipt_long, color: color),
                        ),
                        title: Text('Bill — $month', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LKR ${total.toStringAsFixed(2)}'),
                            if (bill['due_date'] != null)
                              Text('Due: ${bill['due_date']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
