import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NgoDetail extends StatefulWidget {
  final String ngoId;
  const NgoDetail({super.key, required this.ngoId});

  @override
  State<NgoDetail> createState() => _NgoDetailState();
}

class _NgoDetailState extends State<NgoDetail> {
  final Map<String, String> _restaurantNames = {};

  Future<String> _getRestaurantName(String id) async {
    if (_restaurantNames.containsKey(id)) return _restaurantNames[id]!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
    final name = (doc.data() as Map<String, dynamic>?)?['name']?.toString() ?? id;
    _restaurantNames[id] = name;
    return name;
  }

  bool _isRelatedToNgo(Map<String, dynamic> d) {
    final fieldsToCheck = ['ngoId', 'reservedBy', 'claimedBy', 'receiverId', 'reservedNgoId'];
    for (final f in fieldsToCheck) {
      final v = d[f];
      if (v == widget.ngoId) return true;
      if (v is String && v == widget.ngoId) return true;
      if (v is Map && v['id'] == widget.ngoId) return true;
      if (v is List && v.contains(widget.ngoId)) return true;
    }
    if (d['reservationHistory'] is List && (d['reservationHistory'] as List).any((e) => e is Map && e['ngoId'] == widget.ngoId)) return true;
    return false;
  }

  String _donationStatus(Map<String, dynamic> d) {
    final completed = d['completedAt'] != null;
    final expiry = d['expiryAt'] as Timestamp?;
    final expired = expiry != null && expiry.toDate().isBefore(DateTime.now());
    if (completed) return 'Completed';
    if (expired) return 'Expired';
    return 'Active';
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.ngoId);
    final donationsStream = FirebaseFirestore.instance.collection('donations').orderBy('createdAt', descending: true).snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('NGO'), backgroundColor: const Color(0xffd4a373)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) return const Center(child: Text('Error loading NGO'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          final user = userSnap.data!;
          final u = user.data() as Map<String, dynamic>? ?? {};
          return Column(
            children: [
              ListTile(
                title: Text(u['name'] ?? 'No name'),
                subtitle: Text(u['email'] ?? '-'),
                leading: CircleAvatar(child: Text((u['name'] ?? 'N').toString()[0].toUpperCase())),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: donationsStream,
                  builder: (context, snap) {
                    if (snap.hasError) return const Center(child: Text('Error loading donations'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs.map((d) => {'id': d.id, ...?(d.data() as Map<String, dynamic>)}).where((m) => _isRelatedToNgo(m)).toList();
                    if (docs.isEmpty) return const Center(child: Text('No claimed/related donations found'));
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const Divider(),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final status = _donationStatus(d);
                        final qty = d['quantity']?.toString() ?? '-';
                        final title = d['title'] ?? d['details'] ?? 'Donation';
                        final restId = d['restaurantId']?.toString();
                        final explicitName = d['restaurantName']?.toString();

                        Widget fromWidget;
                        if (explicitName != null && explicitName.isNotEmpty) {
                          fromWidget = Text('From: $explicitName');
                        } else if (restId != null && restId.isNotEmpty) {
                          fromWidget = FutureBuilder<String>(
                            future: _getRestaurantName(restId),
                            builder: (ctx, s) {
                              if (s.connectionState == ConnectionState.waiting) return const Text('From: Loading...');
                              if (s.hasError) return Text('From: $restId');
                              return Text('From: ${s.data}');
                            },
                          );
                        } else {
                          fromWidget = const Text('From: Unknown');
                        }

                        return ListTile(
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              fromWidget,
                              Text('Qty: $qty • $status'),
                            ],
                          ),
                          trailing: d['claimedAt'] != null ? Text((d['claimedAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0]) : null,
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