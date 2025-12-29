import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'restaurant_detail.dart';
import 'ngo_detail.dart';

class UserListPage extends StatelessWidget {
  final String role;
  final String title;
  const UserListPage({super.key, required this.role, required this.title});

  @override
  Widget build(BuildContext context) {
    // removed orderBy to avoid index/missing-field errors
    final q = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: role);
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: const Color(0xffd4a373)),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error loading users: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No users found'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? data['email'] ?? 'No name'),
                subtitle: Text(data['email'] ?? '-'),
                trailing: Text(data['approved'] == true ? 'Approved' : 'Pending'),
                onTap: () {
                  if (role == 'restaurant') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetail(restaurantId: d.id)));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NgoDetail(ngoId: d.id)));
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