import 'package:flutter/material.dart';
import 'api_service.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  List<dynamic> rooms = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> loadRooms() async {
    try {
      final data = await ApiService.getRooms();
      if (!mounted) return;
      setState(() {
        rooms = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> showAddRoomDialog({Map<String, dynamic>? roomToEdit}) async {
    final nameCtrl = TextEditingController(text: roomToEdit?['room_name'] ?? '');
    final capacityCtrl = TextEditingController(
        text: roomToEdit != null ? (roomToEdit['capacity']?.toString() ?? '1') : '1');
    final feeCtrl = TextEditingController(
        text: roomToEdit != null ? (roomToEdit['monthly_fee']?.toString() ?? '10000') : '10000');

    final isEditing = roomToEdit != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Room' : 'Add New Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room Name / Number',
                  hintText: 'e.g. Room 101',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity (Students)',
                  hintText: 'e.g. 2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly Fee (LKR)',
                  hintText: 'e.g. 15000',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 0;
              final fee = double.tryParse(feeCtrl.text.trim()) ?? 0.0;

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a room name')),
                );
                return;
              }
              if (capacity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid capacity (> 0)')),
                );
                return;
              }

              try {
                if (isEditing) {
                  await ApiService.updateRoom(
                    id: roomToEdit['id'] as int,
                    roomName: name,
                    capacity: capacity,
                    monthlyFee: fee,
                  );
                } else {
                  await ApiService.addRoom(
                    roomName: name,
                    capacity: capacity,
                    monthlyFee: fee,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Save' : 'Add Room'),
          ),
        ],
      ),
    );

    if (result == true) {
      loadRooms();
    }
  }

  Future<void> confirmDeleteRoom(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteRoom(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room "$name" deleted')),
        );
        loadRooms();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rooms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error loading rooms:\n$errorMessage',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No rooms found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap the button below to add your first room.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => showAddRoomDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Room'),
                          )
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadRooms,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final int roomId = room['id'] ?? 0;
                          final String roomName = room['room_name'] ?? 'Room';
                          final int capacity = room['capacity'] ?? 0;
                          final int studentsCount = room['students_count'] ?? 0;
                          final double monthlyFee =
                              double.tryParse(room['monthly_fee'].toString()) ?? 0;
                          final bool isFull = studentsCount >= capacity;
                          final int availableSpaces = (capacity - studentsCount).clamp(0, capacity);
                          final double occupancy =
                              capacity > 0 ? (studentsCount / capacity).clamp(0.0, 1.0) : 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Room name + status badge + menu
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          roomName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFull
                                              ? Colors.red.withValues(alpha: 0.12)
                                              : Colors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isFull ? 'Full' : 'Available',
                                          style: TextStyle(
                                            color: isFull ? Colors.red[700] : Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            showAddRoomDialog(roomToEdit: room);
                                          } else if (action == 'delete') {
                                            confirmDeleteRoom(roomId, roomName);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Occupancy
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Occupancy',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                      Text(
                                        '$studentsCount / $capacity students',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  LinearProgressIndicator(
                                    value: occupancy,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(10),
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isFull ? Colors.red : Colors.indigo,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Room details
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Monthly Fee',
                                              style: TextStyle(color: Colors.grey[700]),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'LKR ${monthlyFee.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Available Spaces',
                                              style: TextStyle(color: Colors.grey[700]),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$availableSpaces space${availableSpaces == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: availableSpaces > 0
                                                    ? Colors.green[700]
                                                    : Colors.red[700],
                                              ),
                                            ),
                                          ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddRoomDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
    );
  }
}