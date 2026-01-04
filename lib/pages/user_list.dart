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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: widget.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error loading users: ${snap.error}'));
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs;

                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? data['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_query);
                  }).toList();
                }

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

                    final String displayName = data['name'] ?? data['email'] ?? 'User';

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
                          backgroundImage: (data['profileImageUrl'] != null &&
                                  data['profileImageUrl'].toString().isNotEmpty)
                              ? NetworkImage(data['profileImageUrl'])
                              : null,
                          child: (data['profileImageUrl'] == null ||
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
                          color: data['approved'] == true ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        if (widget.role == 'restaurant') {
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
          ),
        ],
      ),
    );
  }
}
