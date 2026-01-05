import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserProfilePage extends StatelessWidget {
  final String userId;

  const AdminUserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final user = snap.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      (user['profileImageUrl'] != null &&
                          user['profileImageUrl'].toString().isNotEmpty)
                      ? NetworkImage(user['profileImageUrl'])
                      : null,
                  child:
                      (user['profileImageUrl'] == null ||
                          user['profileImageUrl'].toString().isEmpty)
                      ? Text(
                          (user['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 20),

                _infoTile('Name', user['name']),
                _infoTile('Email', user['email']),
                _infoTile('Role', user['role']),
                _infoTile('Phone', user['phone']),
                _infoTile('Address', user['address']),
                _infoTile(
                  'Status',
                  user['approved'] == true
                      ? 'Approved'
                      : user['rejected'] == true
                      ? 'Rejected'
                      : 'Pending',
                ),

                if (user['role'] == 'restaurant') ...[
                  const Divider(),
                  _infoTile('Business Reg No', user['businessRegNo']),
                  _infoTile('Opening Time', user['openingTime']),
                  _infoTile('Closing Time', user['closingTime']),
                  _infoTile('Halal', user['halal'] == true ? 'Yes' : 'No'),
                ],

                if (user['role'] == 'ngo') ...[
                  const Divider(),
                  _infoTile('NGO Reg No', user['ngoRegNo']),
                  _infoTile('Coverage Area', user['coverageArea']),
                  _infoTile('Contact Person', user['contactPerson']),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, dynamic value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value?.toString() ?? '-'),
    );
  }
}
