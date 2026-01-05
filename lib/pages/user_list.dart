import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'restaurant_detail.dart';
import 'ngo_detail.dart';
import 'admin_user_profile_page.dart';

class UserListPage extends StatefulWidget {
  final String role;
  final String title;

  const UserListPage({super.key, required this.role, required this.title});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  String _searchQuery = '';
  bool _isAscending = true; // True for A-Z, False for Z-A

  @override
  Widget build(BuildContext context) {
    // Basic query filtered by role
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: widget.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xffd4a373),
        actions: [
          // Sort Button
          IconButton(
            icon: Icon(_isAscending ? Icons.sort_by_alpha : Icons.sort),
            onPressed: () {
              setState(() {
                _isAscending = !_isAscending;
              });
            },
            tooltip: _isAscending ? "Sort Z to A" : "Sort A to Z",
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                // 1. Get docs and filter manually for search (Firestore doesn't support easy partial string search)
                var docs = snap.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                // 2. Sort the list
                docs.sort((a, b) {
                  final nameA = (a.data() as Map<String, dynamic>)['name'] ?? '';
                  final nameB = (b.data() as Map<String, dynamic>)['name'] ?? '';
                  return _isAscending 
                      ? nameA.compareTo(nameB) 
                      : nameB.compareTo(nameA);
                });

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
                    final String displayName = data['name'] ?? data['email'] ?? 'User';

                    return ListTile(
                      leading: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AdminUserProfilePage(userId: d.id)),
                        ),
                        child: CircleAvatar(
                          backgroundImage: (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty)
                              ? NetworkImage(data['profileImageUrl'])
                              : null,
                          child: (data['profileImageUrl'] == null || data['profileImageUrl'].toString().isEmpty)
                              ? Text((data['name'] ?? 'U')[0].toUpperCase())
                              : null,
                        ),
                      ),
                      title: Text(displayName),
                      subtitle: Text(data['email'] ?? '-'),
                      trailing: Text(
                        data['approved'] == true ? 'Approved' : 'Pending',
                        style: TextStyle(
                          color: data['approved'] == true ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        if (widget.role == 'restaurant') {
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
          ),
        ],
      ),
    );
  }
}