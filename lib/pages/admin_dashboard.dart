import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'admin_user_profile_page.dart';

import 'user_list.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; // 0 = Home (stats), 1 = User Verification
  bool _loadingStats = false;
  int restaurantsCount = 0;
  int ngosCount = 0;
  int totalCompletedQuantity = 0;
  int activeDonationQuantity = 0;

  // weekly chart data (last 7 days, oldest -> newest)
  List<int> _weeklyCounts = List<int>.filled(7, 0);
  List<String> _weeklyLabels = List<String>.filled(7, '');

  // user verification filter
  String _userFilter = 'all';
  final Map<String, String> _userFilterLabels = {
    'all': 'All',
    'pending': 'Pending',
    'approved': 'Approved',
  };

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final qRes = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'restaurant')
          .get();
      final qNgo = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .get();

      // completed donations (sum quantities) and collect for weekly chart
      final qDone = await FirebaseFirestore.instance
          .collection('donations')
          .where('completedAt', isNotEqualTo: null)
          .get();

      int sumCompletedQty = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _weeklyCounts = List<int>.filled(7, 0);
      _weeklyLabels = List.generate(7, (i) {
        final d = today.subtract(Duration(days: 6 - i)); // oldest -> newest
        return '${d.day}/${d.month}';
      });

      for (final d in qDone.docs) {
        final data = d.data();
        final q = data['quantity'];
        int qty = 0;
        if (q is int)
          qty = q;
        else if (q is String)
          qty = int.tryParse(q) ?? 0;
        else if (q is double)
          qty = q.toInt();
        sumCompletedQty += qty;

        final completedTs = data['completedAt'] as Timestamp?;
        if (completedTs != null) {
          final completedDate = completedTs.toDate();
          final cd = DateTime(
            completedDate.year,
            completedDate.month,
            completedDate.day,
          );
          final daysAgo = today.difference(cd).inDays; // 0 => today
          if (daysAgo >= 0 && daysAgo <= 6) {
            final idx = 6 - daysAgo; // 0..6 oldest->newest
            _weeklyCounts[idx] += qty;
          }
        }
      }

      // active donations: sum quantities where expiryAt > now AND completedAt == null
      final qActiveCandidates = await FirebaseFirestore.instance
          .collection('donations')
          .where('expiryAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
      int sumActiveQty = 0;
      for (final d in qActiveCandidates.docs) {
        final data = d.data();
        if (data['completedAt'] != null) continue;
        final q = data['quantity'];
        if (q is int)
          sumActiveQty += q;
        else if (q is String)
          sumActiveQty += int.tryParse(q) ?? 0;
        else if (q is double)
          sumActiveQty += q.toInt();
      }

      if (mounted) {
        setState(() {
          restaurantsCount = qRes.docs.length;
          ngosCount = qNgo.docs.length;
          totalCompletedQuantity = sumCompletedQty;
          activeDonationQuantity = sumActiveQty;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load stats: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _approveUser(
    String userId,
    String userEmail,
    String userName,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Processing verification...')));

    String username = 'yoyohuazo1234@gmail.com';
    String password = 'pawv qmfy fuoe xfan';

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'Food4Need Admin')
      ..recipients.add(userEmail)
      ..subject = 'Account Verified: Welcome to Food4Need!'
      ..text =
          '''
Hello $userName,

Good news! Your account has been successfully verified by the Food4Need Admin team.You can now log in to the application and start using all features.

Thank you for joining us in our mission to reach Zero Hunger!

Regards,
Food4Need Team
''';

    try {
      await send(message, smtpServer);
      print('Email sent successfully');
    } catch (e) {
      print('Email failed: $e');
    }

    try {
      // Update Firebase
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'approved': true,
        'rejected': false,
        'verifiedAt':
            FieldValue.serverTimestamp(), // Optional: Track when verified
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide "Processing"
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User approved & Email sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Approve failed: $e')));
      }
    }
  }

  Future<void> _rejectUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User rejected and removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reject failed: $e')));
      }
    }
  }

  Future<void> _confirmDeleteDialog(String userId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to permanently remove this user? This action cannot be undone.',
          ),
          actions: <Widget>[
            // CANCEL BUTTON
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // DELETE BUTTON
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(userId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User deleted')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _openUserList(String role, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserListPage(role: role, title: title),
      ),
    );
  }

  Future<void> _refreshUsers() async {
    await FirebaseFirestore.instance.collection('users').get();
    await _loadStats();
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                const crossAxisCount = 2;
                final availableWidth = constraints.maxWidth;
                final itemWidth =
                    (availableWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                final desiredItemHeight = 160.0;
                final childAspectRatio = itemWidth / desiredItemHeight;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _statCard(
                      label: 'Registered Rest.',
                      value: _loadingStats
                          ? '...'
                          : restaurantsCount.toString(),
                      icon: Icons.restaurant,
                      color: const Color(0xfff6e9de),
                      onTap: () => _openUserList('restaurant', 'Restaurants'),
                    ),
                    _statCard(
                      label: 'Registered NGOs',
                      value: _loadingStats ? '...' : ngosCount.toString(),
                      icon: Icons.groups,
                      color: const Color(0xffe9f6ee),
                      onTap: () => _openUserList('ngo', 'NGOs'),
                    ),
                    _statCard(
                      label: 'Act. Don. Qty',
                      value: _loadingStats
                          ? '...'
                          : activeDonationQuantity.toString(),
                      icon: Icons.hourglass_top,
                      color: const Color(0xfffff4e6),
                    ),
                    _statCard(
                      label: 'Comp. Don. Qty',
                      value: _loadingStats
                          ? '...'
                          : totalCompletedQuantity.toString(),
                      icon: Icons.local_shipping,
                      color: const Color(0xffe9eef6),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final maxYValue = _weeklyCounts.fold<int>(0, (a, b) => max(a, b));
    final maxY = max(1, maxYValue);
    // choose at most 4 intervals for clarity
    final interval = max(1, (maxY / 4).ceil());

    final spots = List.generate(
      _weeklyCounts.length,
      (i) => FlSpot(i.toDouble(), _weeklyCounts[i].toDouble()),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Completed (claimed) items — last 7 days',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _weeklyCounts.every((e) => e == 0)
                  ? Center(
                      child: Text(
                        _loadingStats
                            ? 'Loading chart...'
                            : 'No completed donations in last 7 days',
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (_weeklyCounts.length - 1).toDouble(),
                        minY: 0,
                        maxY: (maxY + interval).toDouble(), // give headroom
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval.toDouble(),
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= _weeklyLabels.length)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _weeklyLabels[idx],
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: interval.toDouble(),
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                // show integer labels only
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.green.shade600,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.shade200.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              'Total claimed items shown: ${_weeklyCounts.fold<int>(0, (a, b) => a + b)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: Colors.black54),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserVerification() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return const Center(child: Text('Error loading users'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs
            .map((d) => {'id': d.id, ...?d.data() as Map<String, dynamic>})
            .where(
              (m) =>
                  m['id'] != _currentUid &&
                  (m['role'] == 'restaurant' || m['role'] == 'ngo'),
            )
            .toList();

        docs.sort((a, b) {
          final aa = a['approved'] == true ? 1 : 0;
          final bb = b['approved'] == true ? 1 : 0;
          return aa.compareTo(bb);
        });

        final filtered = docs.where((m) {
          final approved = m['approved'] == true;
          if (_userFilter == 'all') return true;
          if (_userFilter == 'pending') return !approved;
          if (_userFilter == 'approved') return approved;
          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 8,
                children: _userFilterLabels.entries.map((e) {
                  final key = e.key;
                  final label = e.value;
                  final selected = _userFilter == key;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (v) {
                      if (!v || selected) return;
                      setState(() => _userFilter = key);
                    },
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No users found'))
                  : RefreshIndicator(
                      onRefresh: _refreshUsers,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        separatorBuilder: (_, __) => const Divider(),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final u = filtered[i];
                          final approved = u['approved'] == true;
                          final role = (u['role'] ?? '').toString();

                          return Card(
                            child: ListTile(
                              title: Text(u['name'] ?? u['email'] ?? 'No name'),
                              subtitle: Text(
                                '${u['email'] ?? '-'} • ${role.toUpperCase()}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!approved) ...[
                                    TextButton(
                                      onPressed: () => _approveUser(
                                        u['id'],
                                        u['email'] ?? '',
                                        u['name'] ?? 'User',
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _confirmDeleteDialog(u['id']),
                                      child: const Text(
                                        'Reject',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ] else ...[
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(u['id'])
                                            .update({'role': v});
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'restaurant',
                                          child: Text('Set Restaurant'),
                                        ),
                                        PopupMenuItem(
                                          value: 'ngo',
                                          child: Text('Set NGO'),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteDialog(u['id']),
                                    ),
                                  ],
                                ],
                              ),
                              leading: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminUserProfilePage(userId: u['id']),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage:
                                      (u['profileImageUrl'] != null &&
                                          (u['profileImageUrl'] as String)
                                              .isNotEmpty)
                                      ? NetworkImage(u['profileImageUrl'])
                                      : null,
                                  child:
                                      (u['profileImageUrl'] == null ||
                                          (u['profileImageUrl'] as String)
                                              .isEmpty)
                                      ? Text(
                                          (u['name'] ?? 'U')
                                              .toString()[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == 0
        ? 'Admin — Home'
        : 'Admin — User Verification';
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xffd4a373)),
                child: const Text(
                  'Admin Menu',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                selected: _selectedIndex == 0,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('User Verification'),
                selected: _selectedIndex == 1,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Recent Activity'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin-activity');
                },
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('List of NGOs'),
                onTap: () {
                  Navigator.pop(context);
                  _openUserList('ngo', 'NGOs');
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('List of Restaurants'),
                onTap: () {
                  Navigator.pop(context);
                  _openUserList('restaurant', 'Restaurants');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (mounted)
                    Navigator.pushReplacementNamed(context, "/login");
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: _selectedIndex == 0 ? _buildHome() : _buildUserVerification(),
    );
  }
}
