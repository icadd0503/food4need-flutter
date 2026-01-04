import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Shows a specific restaurant's profile, a chart of their recent activity,
// and a complete history of their donations.
class RestaurantDetail extends StatefulWidget {
  final String restaurantId;
  const RestaurantDetail({super.key, required this.restaurantId});

  @override
  State<RestaurantDetail> createState() => _RestaurantDetailState();
}

class _RestaurantDetailState extends State<RestaurantDetail> {
  // Cache NGO names here to prevent repeated Firestore reads while scrolling.
  final Map<String, String> _ngoNames = {};

  // Generates date labels (dd/MM) for the last 7 days for the chart x-axis.
  List<String> get _last7Labels {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return '${d.day}/${d.month}';
    });
  }

  // Fetches NGO name given an ID, checking the cache first.
  Future<String> _getNgoName(String id) async {
    if (_ngoNames.containsKey(id)) return _ngoNames[id]!;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(id).get();
    final name =
        (doc.data() as Map<String, dynamic>?)?['name']?.toString() ?? id;
    _ngoNames[id] = name;
    return name;
  }

  // Determines the visual status of a donation based on timestamps.
  String _donationStatus(Map<String, dynamic> d) {
    final completed = d['completedAt'] != null;
    final expiry = d['expiryAt'] as Timestamp?;
    final expired =
        expiry != null && expiry.toDate().isBefore(DateTime.now());
    if (completed) return 'Completed';
    if (expired) return 'Expired';
    return 'Active';
  }

  // extract the NGO ID from various possible fields in the donation doc.
  String? _findNgoId(Map<String, dynamic> d) {
    final candidates = [
      'ngoId',
      'claimedBy',
      'reservedBy',
      'receiverId',
      'reservedNgoId'
    ];
    for (final k in candidates) {
      final v = d[k];
      if (v is String && v.isNotEmpty) return v;
      if (v is Map && v['id'] is String) return v['id'] as String;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.restaurantId);
    final donationsQuery = FirebaseFirestore.instance
        .collection('donations')
        .where('restaurantId', isEqualTo: widget.restaurantId)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Restaurant'),
          backgroundColor: const Color(0xffd4a373)),
      // First Stream: Get Restaurant User Details
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError)
            return const Center(child: Text('Error loading restaurant'));
          if (!userSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          final user = userSnap.data!;
          final u = user.data() as Map<String, dynamic>? ?? {};

          // Second Stream: Get Donations for this Restaurant
          return StreamBuilder<QuerySnapshot>(
            stream: donationsQuery.snapshots(),
            builder: (context, snap) {
              if (snap.hasError)
                return const Center(child: Text('Error loading donations'));
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;

              // Aggregate data for the Chart: Sum quantities completed in the last 7 days.
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final dailyClaimed = List<int>.filled(7, 0);

              for (final doc in docs) {
                final d = doc.data() as Map<String, dynamic>;
                final ts = d['completedAt'] as Timestamp?;
                if (ts != null) {
                  final dt = ts.toDate();
                  final cd = DateTime(dt.year, dt.month, dt.day);
                  final daysAgo = today.difference(cd).inDays;
                  if (daysAgo >= 0 && daysAgo <= 6) {
                    final idx = 6 - daysAgo;
                    final q = d['quantity'];
                    int qty = 0;
                    if (q is int)
                      qty = q;
                    else if (q is String)
                      qty = int.tryParse(q) ?? 0;
                    else if (q is double) qty = q.toInt();
                    dailyClaimed[idx] += qty;
                  }
                }
              }
              final maxY =
                  (dailyClaimed.reduce((a, b) => a > b ? a : b)).toDouble() + 2;

              return Column(
                children: [
                  // 1. Restaurant Header Info
                  ListTile(
                    title: Text(u['name'] ?? 'No name'),
                    subtitle: Text(u['email'] ?? '-'),
                    leading: CircleAvatar(
                        child: Text(
                            (u['name'] ?? 'R').toString()[0].toUpperCase())),
                  ),
                  const Divider(),

                  // 2. Weekly Activity Chart
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Claimed Items (last 7 days)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  minX: 0,
                                  maxX: 6,
                                  minY: 0,
                                  maxY: maxY,
                                  gridData: FlGridData(
                                      show: true, drawVerticalLine: false),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 ||
                                              idx >= _last7Labels.length)
                                            return const SizedBox.shrink();
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(_last7Labels[idx],
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false),
                                    ),
                                    topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: List.generate(
                                          7,
                                          (i) => FlSpot(i.toDouble(),
                                              dailyClaimed[i].toDouble())),
                                      isCurved: true,
                                      color: Colors.blue,
                                      barWidth: 3,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.blue.shade100
                                              .withOpacity(0.4)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Total Claimed Items (last 7 days):',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                            Text('${dailyClaimed.reduce((a, b) => a + b)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),

                  // 3. Donation List with Async NGO Name Loading
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(child: Text('No donations posted'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final d = docs[i].data() as Map<String, dynamic>;
                              final status = _donationStatus(d);
                              final qty = d['quantity']?.toString() ?? '-';
                              final title = d['title'] ??
                                  d['details'] ??
                                  'Donation';
                              final explicitNgoName =
                                  d['ngoName']?.toString();
                              final ngoId = _findNgoId(d);

                              Widget claimedWidget = const SizedBox.shrink();
                              if (explicitNgoName != null &&
                                  explicitNgoName.isNotEmpty) {
                                claimedWidget =
                                    Text('Claimed by: $explicitNgoName');
                              } else if (ngoId != null &&
                                  ngoId.isNotEmpty) {
                                claimedWidget = FutureBuilder<String>(
                                  future: _getNgoName(ngoId),
                                  builder: (ctx, s) {
                                    if (s.connectionState ==
                                        ConnectionState.waiting)
                                      return const Text(
                                          'Claimed by: Loading...');
                                    if (s.hasError)
                                      return Text('Claimed by: $ngoId');
                                    return Text('Claimed by: ${s.data}');
                                  },
                                );
                              }

                              return ListTile(
                                title: Text(title),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Qty: $qty • $status'),
                                    if ((explicitNgoName?.isNotEmpty ??
                                            false) ||
                                        (ngoId != null))
                                      const SizedBox(height: 6),
                                    if ((explicitNgoName?.isNotEmpty ??
                                            false) ||
                                        (ngoId != null))
                                      claimedWidget,
                                  ],
                                ),
                                trailing: d['expiryAt'] != null
                                    ? Text((d['expiryAt'] as Timestamp)
                                        .toDate()
                                        .toLocal()
                                        .toString()
                                        .split(' ')[0])
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}