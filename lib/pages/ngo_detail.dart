import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class NgoDetail extends StatefulWidget {
  final String ngoId;
  const NgoDetail({super.key, required this.ngoId});

  @override
  State<NgoDetail> createState() => _NgoDetailState();
}

class _NgoDetailState extends State<NgoDetail> {
  final Map<String, String> _restaurantNames = {};

  // Caches restaurant names to avoid redundant Firestore lookups
  Future<String> _getRestaurantName(String id) async {
    if (_restaurantNames.containsKey(id)) return _restaurantNames[id]!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
    final name = (doc.data() as Map<String, dynamic>?)?['name']?.toString() ?? id;
    _restaurantNames[id] = name;
    return name;
  }

  // Identifies if a donation document is linked to this specific NGO
  bool _isRelatedToNgo(Map<String, dynamic> d) {
    final fieldsToCheck = ['ngoId', 'reservedBy', 'claimedBy', 'receiverId', 'reservedNgoId'];
    for (final f in fieldsToCheck) {
      final v = d[f];
      if (v == widget.ngoId) return true;
      if (v is String && v == widget.ngoId) return true;
      if (v is Map && v['id'] == widget.ngoId) return true;
      if (v is List && v.contains(widget.ngoId)) return true;
    }
    if (d['reservationHistory'] is List && 
       (d['reservationHistory'] as List).any((e) => e is Map && e['ngoId'] == widget.ngoId)) return true;
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
    final DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Details'), 
        backgroundColor: const Color(0xffd4a373),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) return const Center(child: Text('Error loading NGO'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final u = userSnap.data!.data() as Map<String, dynamic>? ?? {};

          return StreamBuilder<QuerySnapshot>(
            // Single Stream: Fetching all donations to process locally
            stream: FirebaseFirestore.instance.collection('donations').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Error loading donations'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              // Filter documents related to this NGO in memory for the list
              final allRelatedDocs = snap.data!.docs
                  .map((d) => {'id': d.id, ...?(d.data() as Map<String, dynamic>)})
                  .where((m) => _isRelatedToNgo(m))
                  .toList();

              // --- CHART DATA PROCESSING ---
              Map<String, double> dailyTotals = {};
              List<String> last7DaysLabels = [];
              for (int i = 6; i >= 0; i--) {
                String date = DateFormat('MM/dd').format(DateTime.now().subtract(Duration(days: i)));
                dailyTotals[date] = 0.0;
                last7DaysLabels.add(date);
              }

              double maxClaimValue = 0;
              for (var d in allRelatedDocs) {
                final Timestamp? ts = d['createdAt'] as Timestamp?;
                if (ts != null) {
                  DateTime date = ts.toDate();
                  if (date.isAfter(sevenDaysAgo)) {
                    String formattedDate = DateFormat('MM/dd').format(date);
                    if (dailyTotals.containsKey(formattedDate)) {
                      double qty = double.tryParse(d['quantity']?.toString() ?? '0') ?? 0;
                      dailyTotals[formattedDate] = dailyTotals[formattedDate]! + qty;
                      if (dailyTotals[formattedDate]! > maxClaimValue) {
                        maxClaimValue = dailyTotals[formattedDate]!;
                      }
                    }
                  }
                }
              }

              List<FlSpot> spots = [];
              for (int i = 0; i < last7DaysLabels.length; i++) {
                spots.add(FlSpot(i.toDouble(), dailyTotals[last7DaysLabels[i]]!));
              }

              double calculatedMaxY = maxClaimValue == 0 ? 5 : maxClaimValue * 1.2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. NGO Profile Header
                  Container(
                    color: const Color(0xffd4a373),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(u['name'] ?? 'No name', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                      subtitle: Text(u['email'] ?? '-', style: const TextStyle(color: Colors.white70)),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text((u['name'] ?? 'N').toString()[0].toUpperCase(), 
                          style: const TextStyle(color: Color(0xffd4a373), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text("Collection Performance (7 Days)", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),

                  // 2. NGO Collection Graph
                  Container(
                    height: 180,
                    padding: const EdgeInsets.fromLTRB(10, 10, 25, 10),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: calculatedMaxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, _) {
                                int idx = val.toInt();
                                if (idx < 0 || idx >= last7DaysLabels.length) return const Text('');
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(last7DaysLabels[idx], style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, 
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                if (value % 1 != 0) return Container();
                                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true, 
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                            left: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: const Color(0xffd4a373),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true, 
                              color: const Color(0xffd4a373).withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text("Collection History", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),

                  // 3. Related Donations List
                  Expanded(
                    child: allRelatedDocs.isEmpty
                        ? const Center(child: Text('No claimed/related donations found'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: allRelatedDocs.length,
                            itemBuilder: (context, i) {
                              final d = allRelatedDocs[i];
                              final status = _donationStatus(d);
                              final qty = d['quantity']?.toString() ?? '-';
                              final title = d['title'] ?? d['details'] ?? 'Donation';
                              final restId = d['restaurantId']?.toString();
                              final explicitName = d['restaurantName']?.toString();

                              return ListTile(
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (explicitName != null && explicitName.isNotEmpty) 
                                      Text('From: $explicitName')
                                    else if (restId != null)
                                      FutureBuilder<String>(
                                        future: _getRestaurantName(restId),
                                        builder: (ctx, s) => Text('From: ${s.data ?? "..."}'),
                                      ),
                                    Text('Qty: $qty • $status'),
                                  ],
                                ),
                                trailing: d['claimedAt'] != null 
                                    ? Text(DateFormat('MMM dd').format((d['claimedAt'] as Timestamp).toDate()),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey))
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