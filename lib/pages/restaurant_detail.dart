import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
    if (d['completedAt'] != null) return 'Completed';
    final expiry = d['expiryAt'] as Timestamp?;
    if (expiry != null && expiry.toDate().isBefore(DateTime.now())) return 'Expired';
    return 'Active';
  }

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
    final DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Details'),
        backgroundColor: const Color(0xffd4a373),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.restaurantId).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          final u = userSnap.data!.data() as Map<String, dynamic>? ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('donations')
                .where('restaurantId', isEqualTo: widget.restaurantId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, donationSnap) {
              if (donationSnap.hasError) return Center(child: Text('Error: ${donationSnap.error}'));
              if (!donationSnap.hasData) return const Center(child: CircularProgressIndicator());

              final allDocs = donationSnap.data!.docs;

              Map<String, double> dailyTotals = {};
              List<String> last7DaysLabels = [];
              for (int i = 6; i >= 0; i--) {
                String date = DateFormat('MM/dd').format(DateTime.now().subtract(Duration(days: i)));
                dailyTotals[date] = 0.0;
                last7DaysLabels.add(date);
              }

              double maxDonationValue = 0;
              for (var doc in allDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final Timestamp? ts = data['createdAt'] as Timestamp?;
                if (ts != null) {
                  DateTime date = ts.toDate();
                  if (date.isAfter(sevenDaysAgo)) {
                    String formattedDate = DateFormat('MM/dd').format(date);
                    if (dailyTotals.containsKey(formattedDate)) {
                      double qty = double.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
                      dailyTotals[formattedDate] = dailyTotals[formattedDate]! + qty;
                      if (dailyTotals[formattedDate]! > maxDonationValue) {
                        maxDonationValue = dailyTotals[formattedDate]!;
                      }
                    }
                  }
                }
              }

              List<FlSpot> spots = [];
              for (int i = 0; i < last7DaysLabels.length; i++) {
                spots.add(FlSpot(i.toDouble(), dailyTotals[last7DaysLabels[i]]!));
              }

              double calculatedMaxY = maxDonationValue == 0 ? 5 : maxDonationValue * 1.2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: const Color(0xffd4a373),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(u['name'] ?? 'No name', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                      subtitle: Text(u['email'] ?? '-', style: const TextStyle(color: Colors.white70)),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text((u['name'] ?? 'R').toString()[0].toUpperCase(), 
                          style: const TextStyle(color: Color(0xffd4a373), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text("Donation Performance (7 Days)", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),

                  Container(
                    height: 200,
                    padding: const EdgeInsets.fromLTRB(10, 10, 25, 10),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: calculatedMaxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '${spot.y.toInt()} items',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList();
                            },
                          ),
                        ),
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
                                // --- FIXED LINE BELOW ---
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
                    child: Text("Recent Donation Activity", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),

                  Expanded(
                    child: allDocs.isEmpty
                        ? const Center(child: Text('No donations posted yet'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: allDocs.length,
                            itemBuilder: (context, i) {
                              final d = allDocs[i].data() as Map<String, dynamic>;
                              final status = _donationStatus(d);
                              final qty = d['quantity']?.toString() ?? '0';
                              final title = d['title'] ?? d['details'] ?? 'Donation';
                              final ngoId = _findNgoId(d);

                              return ListTile(
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Qty: $qty • $status', 
                                      style: TextStyle(color: status == 'Active' ? Colors.green : Colors.grey)),
                                    if (ngoId != null)
                                      FutureBuilder<String>(
                                        future: _getNgoName(ngoId),
                                        builder: (context, s) => Text(
                                          'Claimed by: ${s.data ?? "..."}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: d['createdAt'] != null
                                    ? Text(DateFormat('MMM dd, yyyy').format((d['createdAt'] as Timestamp).toDate()),
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