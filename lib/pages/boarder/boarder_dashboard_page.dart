import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../api_service.dart';
import '../../models/user_model.dart';

/// Simplified dashboard shown to boarders after login.
/// Shows their profile, bills summary and quick actions.
class BoarderDashboardPage extends StatefulWidget {
  const BoarderDashboardPage({super.key});

  @override
  State<BoarderDashboardPage> createState() => _BoarderDashboardPageState();
}

class _BoarderDashboardPageState extends State<BoarderDashboardPage> {
  AppUser? _user;
  List<dynamic> _myBills = [];
  int _unreadNotifications = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = _user;
      if (user == null) return;

      // Fetch bills for this boarder's linked student
      List<dynamic> bills = [];
      if (user.linkedStudentId != null) {
        bills = await ApiService.getMonthlyBills(studentId: user.linkedStudentId);
      }

      final unread = await ApiService.getUnreadNotificationCount(user.id);

      if (!mounted) return;
      setState(() {
        _myBills             = bills;
        _unreadNotifications = unread;
        _isLoading           = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalUnpaid {
    return _myBills
        .where((b) => b['status'] == 'unpaid')
        .fold(0.0, (sum, b) => sum + ((b['total'] as num?)?.toDouble() ?? 0.0));
  }

  int get _unpaidCount => _myBills.where((b) => b['status'] == 'unpaid').length;

  @override
  Widget build(BuildContext context) {
    final user   = _user;
    final theme  = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? 'My Account', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => Navigator.pushNamed(context, '/notifications').then((_) => _load()),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'logout') {
                await AuthService.instance.logout();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Row(
                children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Sign Out')],
              )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${user?.name.split(' ').first ?? 'Boarder'}! 👋',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Here is your account summary.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats row
                    Row(
                      children: [
                        Expanded(child: _statCard('Unpaid Bills', '$_unpaidCount', Icons.receipt_long, Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard('Amount Due', 'LKR ${_totalUnpaid.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.red)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recent bills
                    const Text('Recent Bills',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (_myBills.isEmpty)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No bills yet.', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      )
                    else
                      ...(_myBills.take(5).map((bill) => _billCard(bill, colors))),

                    if (_myBills.length > 5)
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/my-bills'),
                        child: const Text('View All Bills'),
                      ),
                  ],
                ),
              ),
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
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _billCard(dynamic bill, ColorScheme colors) {
    final status = bill['status'] as String? ?? 'unpaid';
    final total  = (bill['total'] as num?)?.toDouble() ?? 0.0;
    final month  = bill['month'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'paid':
        statusColor  = Colors.green;
        statusLabel  = 'Paid';
        break;
      case 'pending_approval':
        statusColor  = Colors.blue;
        statusLabel  = 'Pending';
        break;
      default:
        statusColor  = Colors.orange;
        statusLabel  = 'Unpaid';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.receipt_long, color: statusColor),
        ),
        title: Text('Bill for $month', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('LKR ${total.toStringAsFixed(0)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusLabel,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }
}
