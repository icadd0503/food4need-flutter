import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'restaurant_detail.dart';
import 'ngo_detail.dart';
import 'admin_user_profile_page.dart';

class UserListPage extends StatelessWidget {
  final String role;
  final String title;

  const UserListPage({super.key, required this.role, required this.title});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: role);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error loading users: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;

              final String? imageUrl =
                  data.containsKey('profileImageUrl') &&
                      data['profileImageUrl'] != null &&
                      data['profileImageUrl'] is String &&
                      (data['profileImageUrl'] as String).isNotEmpty
                  ? data['profileImageUrl']
                  : null;

              final String displayName =
                  data['name'] ?? data['email'] ?? 'User';

              return ListTile(
                leading: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminUserProfilePage(userId: d.id),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage:
                        (data['profileImageUrl'] != null &&
                            data['profileImageUrl'].toString().isNotEmpty)
                        ? NetworkImage(data['profileImageUrl'])
                        : null,
                    child:
                        (data['profileImageUrl'] == null ||
                            data['profileImageUrl'].toString().isEmpty)
                        ? Text((data['name'] ?? 'U')[0].toUpperCase())
                        : null,
                  ),
                ),

                title: Text(displayName),
                subtitle: Text(data['email'] ?? '-'),
                trailing: Text(
                  data['approved'] == true ? 'Approved' : 'Pending',
                  style: TextStyle(
                    color: data['approved'] == true
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  if (role == 'restaurant') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetail(restaurantId: d.id),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NgoDetail(ngoId: d.id)),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
