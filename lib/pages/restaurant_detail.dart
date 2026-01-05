import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestaurantDetail extends StatefulWidget {
  final String restaurantId;
  const RestaurantDetail({super.key, required this.restaurantId});

  @override
  State<RestaurantDetail> createState() => _RestaurantDetailState();
}

class _RestaurantDetailState extends State<RestaurantDetail> {
  final Map<String, String> _ngoNames = {};

  Future<String> _getNgoName(String id) async {
    if (_ngoNames.containsKey(id)) return _ngoNames[id]!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
    final name = (doc.data() as Map<String, dynamic>?)?['name']?.toString() ?? id;
    _ngoNames[id] = name;
    return name;
  }

  String _donationStatus(Map<String, dynamic> d) {
    final completed = d['completedAt'] != null;
    final expiry = d['expiryAt'] as Timestamp?;
    final expired = expiry != null && expiry.toDate().isBefore(DateTime.now());
    if (completed) return 'Completed';
    if (expired) return 'Expired';
    return 'Active';
  }

  // find potential NGO identifier from donation document
  String? _findNgoId(Map<String, dynamic> d) {
    final candidates = ['ngoId', 'claimedBy', 'reservedBy', 'receiverId', 'reservedNgoId'];
    for (final k in candidates) {
      final v = d[k];
      if (v is String && v.isNotEmpty) return v;
      if (v is Map && v['id'] is String) return v['id'] as String;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.restaurantId);
    final donationsQuery = FirebaseFirestore.instance
        .collection('donations')
        .where('restaurantId', isEqualTo: widget.restaurantId)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant'), backgroundColor: const Color(0xffd4a373)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) return const Center(child: Text('Error loading restaurant'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          final user = userSnap.data!;
          final u = user.data() as Map<String, dynamic>? ?? {};
          return Column(
            children: [
              ListTile(
                title: Text(u['name'] ?? 'No name'),
                subtitle: Text(u['email'] ?? '-'),
                leading: CircleAvatar(child: Text((u['name'] ?? 'R').toString()[0].toUpperCase())),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: donationsQuery.snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return const Center(child: Text('Error loading donations'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No donations posted'));
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const Divider(),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final status = _donationStatus(d);
                        final qty = d['quantity']?.toString() ?? '-';
                        final title = d['title'] ?? d['details'] ?? 'Donation';
                        final explicitNgoName = d['ngoName']?.toString();
                        final ngoId = _findNgoId(d);

                        Widget claimedWidget = const SizedBox.shrink();
                        if (explicitNgoName != null && explicitNgoName.isNotEmpty) {
                          claimedWidget = Text('Claimed by: $explicitNgoName');
                        } else if (ngoId != null && ngoId.isNotEmpty) {
                          claimedWidget = FutureBuilder<String>(
                            future: _getNgoName(ngoId),
                            builder: (ctx, s) {
                              if (s.connectionState == ConnectionState.waiting) return const Text('Claimed by: Loading...');
                              if (s.hasError) return Text('Claimed by: $ngoId');
                              return Text('Claimed by: ${s.data}');
                            },
                          );
                        }

                        return ListTile(
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Qty: $qty • $status'),
                              if ((explicitNgoName?.isNotEmpty ?? false) || (ngoId != null)) const SizedBox(height: 6),
                              if ((explicitNgoName?.isNotEmpty ?? false) || (ngoId != null)) claimedWidget,
                            ],
                          ),
                          trailing: d['expiryAt'] != null ? Text((d['expiryAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0]) : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}