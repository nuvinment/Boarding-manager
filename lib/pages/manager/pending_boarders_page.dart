import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../models/user_model.dart';

/// Manager view: list of pending boarder registrations.
/// Manager can approve (and assign room+student record) or reject each one.
class PendingBoardersPage extends StatefulWidget {
  const PendingBoardersPage({super.key});

  @override
  State<PendingBoardersPage> createState() => _PendingBoardersPageState();
}

class _PendingBoardersPageState extends State<PendingBoardersPage> {
  List<AppUser> _pending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getPendingBoarders();
      if (!mounted) return;
      setState(() { _pending = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approve(AppUser user) async {
    // 1. Pick room
    final rooms = await ApiService.getRooms();
    if (!mounted) return;

    // Filter rooms with available space
    final available = rooms.where((r) {
      final cap    = (r['capacity'] as int?) ?? 0;
      final count  = (r['students_count'] as int?) ?? 0;
      return count < cap;
    }).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rooms with available space. Please add or free up a room first.')),
      );
      return;
    }

    Map<String, dynamic>? selectedRoom;
    final nameCtrl      = TextEditingController(text: user.name);
    final phoneCtrl     = TextEditingController(text: user.phone ?? '');
    final joinDateCtrl  = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Approve ${user.name}')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Email: ${user.email ?? '-'}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                const Text('Assign to room:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Select Room',
                  ),
                  items: available.map<DropdownMenuItem<Map<String, dynamic>>>((r) {
                    final cap   = (r['capacity'] as int?) ?? 0;
                    final count = (r['students_count'] as int?) ?? 0;
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: r,
                      child: Text('${r['room_name']} ($count/$cap occupied)'),
                    );
                  }).toList(),
                  onChanged: (v) => setSt(() => selectedRoom = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: joinDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Move-in Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedRoom == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Approve & Assign'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedRoom == null || !mounted) return;

    try {
      // Create student record
      final result = await ApiService.addStudent(
        roomId:   selectedRoom!['id'] as int,
        name:     nameCtrl.text.trim(),
        phone:    phoneCtrl.text.trim(),
        joinDate: joinDateCtrl.text.trim(),
      );
      final int studentId = (result['student'] as Map)['id'] as int;

      // Approve user account and link to student
      await ApiService.approveAndLinkBoarder(userId: user.id, studentId: studentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} approved and assigned to ${selectedRoom!['room_name']}!')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Text('Are you sure you want to reject ${user.name}\'s registration? '
            'They will not be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.rejectBoarder(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name}\'s registration has been rejected.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                      const SizedBox(height: 12),
                      const Text('No pending registrations',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('All boarder registrations are up to date.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pending.length,
                    itemBuilder: (context, index) {
                      final user = _pending[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(user.email ?? '-',
                                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Pending',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (user.phone != null && user.phone!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(user.phone!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      onPressed: () => _reject(user),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () => _approve(user),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
