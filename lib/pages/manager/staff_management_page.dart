import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../models/user_model.dart';
import '../../auth/auth_service.dart';

/// Manager/SuperAdmin view to create and manage staff accounts.
class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  List<AppUser> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getAllStaff();
      if (!mounted) return;
      setState(() { _staff = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAccount() async {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl   = TextEditingController();
    final pin2Ctrl  = TextEditingController();

    UserRole selectedRole = UserRole.staff;
    final Set<StaffPermission> selectedPermissions = {};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Create Staff Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(nameCtrl,  'Full Name',       Icons.person_outline),
                const SizedBox(height: 10),
                _buildField(emailCtrl, 'Email Address',   Icons.email_outlined,   TextInputType.emailAddress),
                const SizedBox(height: 10),
                _buildField(phoneCtrl, 'Phone Number',    Icons.phone_outlined,   TextInputType.phone),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '6-digit PIN',
                    prefixIcon: Icon(Icons.pin),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pin2Ctrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    prefixIcon: Icon(Icons.pin),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Role', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [UserRole.manager, UserRole.staff].map<DropdownMenuItem<UserRole>>((r) =>
                    DropdownMenuItem<UserRole>(value: r, child: Text(r.displayName))).toList(),
                  onChanged: (v) => setSt(() => selectedRole = v ?? UserRole.staff),
                ),
                if (selectedRole == UserRole.staff) ...[
                  const SizedBox(height: 14),
                  const Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...StaffPermission.values.map((p) => CheckboxListTile(
                    dense: true,
                    title: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                    value: selectedPermissions.contains(p),
                    onChanged: (v) => setSt(() {
                      if (v == true) { selectedPermissions.add(p); }
                      else { selectedPermissions.remove(p); }
                    }),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                  return;
                }
                if (pinCtrl.text.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN must be 6 digits.')));
                  return;
                }
                if (pinCtrl.text != pin2Ctrl.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PINs do not match.')));
                  return;
                }
                try {
                  await ApiService.createStaffAccount(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    pin: pinCtrl.text,
                    role: selectedRole,
                    permissions: selectedPermissions.toList(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Staff account created successfully!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
                    );
                  }
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  TextField _buildField(TextEditingController c, String label, IconData icon,
      [TextInputType type = TextInputType.text]) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return Colors.deepPurple;
      case UserRole.manager:   return Colors.indigo;
      case UserRole.staff:     return Colors.teal;
      default:                 return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final canCreate   = currentUser?.role.isManagerOrAbove ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
              ? const Center(child: Text('No staff accounts found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final user  = _staff[index];
                    final color = _roleColor(user.role);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email ?? '-', style: const TextStyle(fontSize: 12)),
                            if (user.role == UserRole.staff && user.permissions.isNotEmpty)
                              Text(
                                'Permissions: ${user.permissions.map((p) => p.name).join(', ')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.role.displayName,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _createAccount,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff'),
            )
          : null,
    );
  }
}
