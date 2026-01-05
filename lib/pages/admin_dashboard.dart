import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'admin_user_profile_page.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

import 'user_list.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // State variables for navigation, loading status, and statistics
  int _selectedIndex = 0;
  bool _loadingStats = false;
  int restaurantsCount = 0;
  int ngosCount = 0;
  int totalCompletedQuantity = 0;
  int activeDonationQuantity = 0;
  int expiredDonationQuantity = 0;

  // Chart view: '7days', 'month'
  String _chartView = '7days';

  // State for Specific Month/Year selection
  // Defaults to current date, but we will clamp logic in the UI
  int _selectedYear = DateTime.now().year < 2025 ? 2025 : DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Data holders for the charts
  List<int> _weeklyCounts = List<int>.filled(7, 0); // Last 7 days
  List<String> _weeklyLabels = List<String>.filled(7, '');

  // Data holder for the specific selected month (up to 31 days)
  List<int> _dailyCountsForSelectedMonth = [];
  List<String> _dailyLabelsForSelectedMonth = [];

  // Filter state for the User Verification tab
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

  // Fetches dashboard statistics, chart data, and calculates totals from Firestore
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

      final qDone = await FirebaseFirestore.instance
          .collection('donations')
          .where('completedAt', isNotEqualTo: null)
          .get();

      int sumCompletedQty = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // --- 1. Prepare "Last 7 Days" Data ---
      _weeklyCounts = List<int>.filled(7, 0);
      _weeklyLabels = List.generate(7, (i) {
        final d = today.subtract(Duration(days: 6 - i));
        return '${d.day}/${d.month}';
      });

      // --- 2. Prepare "Specific Month" Data ---
      // Get number of days in the selected month
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      _dailyCountsForSelectedMonth = List<int>.filled(daysInMonth, 0);
      _dailyLabelsForSelectedMonth = List.generate(daysInMonth, (i) {
        return '${i + 1}/$_selectedMonth';
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

          // Logic for Last 7 Days
          final daysAgo = today.difference(cd).inDays;
          if (daysAgo >= 0 && daysAgo <= 6) {
            final idx = 6 - daysAgo;
            _weeklyCounts[idx] += qty;
          }

          // Logic for Specific Selected Month/Year
          if (completedDate.year == _selectedYear &&
              completedDate.month == _selectedMonth) {
            // Day 1 is index 0
            final dayIdx = completedDate.day - 1;
            if (dayIdx >= 0 && dayIdx < daysInMonth) {
              _dailyCountsForSelectedMonth[dayIdx] += qty;
            }
          }
        }
      }

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

      final qExpiredCandidates = await FirebaseFirestore.instance
          .collection('donations')
          .where('expiryAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();
      int sumExpiredQty = 0;
      for (final d in qExpiredCandidates.docs) {
        final data = d.data();
        if (data['completedAt'] != null) continue;
        final q = data['quantity'];
        if (q is int)
          sumExpiredQty += q;
        else if (q is String)
          sumExpiredQty += int.tryParse(q) ?? 0;
        else if (q is double)
          sumExpiredQty += q.toInt();
      }

      if (mounted) {
        setState(() {
          restaurantsCount = qRes.docs.length;
          ngosCount = qNgo.docs.length;
          totalCompletedQuantity = sumCompletedQty;
          activeDonationQuantity = sumActiveQty;
          expiredDonationQuantity = sumExpiredQty;
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

  // Sends verification email via SMTP and updates user status to approved in Firestore
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
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'approved': true,
        'rejected': false,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar();
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

  // Deletes the user document from Firestore (Rejection)
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

  // Shows a confirmation dialog before deleting a user
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
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
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

  final String _apiKey = 'AIzaSyBsDPFpc4_YhNLe7e8AyrnVE-Xsu_rZBXw';
  bool _isGeneratingReport = false;

 Future<String> _generateAIInsight() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Or 'gemini-1.5-flash'
        apiKey: _apiKey,
      );

      final prompt = '''
      You are a strategic advisor for "Food4Need". Write an **impressive, professional Executive Impact Report** (approx 100 words).
      
      **Format:**
      - Write exactly **two distinct paragraphs**.
      - Paragraph 1: Analyze the current performance and food rescue metrics.
      - Paragraph 2: Focus on the environmental impact, community value, and future outlook.
      - Tone: Inspiring, corporate, and authoritative.
      
      **Data:**
      - Total Food Rescued: $totalCompletedQuantity kg
      - Active Ecosystem: $restaurantsCount Restaurants, $ngosCount NGOs.
      - 7-Day Trend: ${_weeklyCounts.join(', ')}.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text ?? "Great progress this week. The platform continues to grow.";
    } catch (e) {
      print("🔴 AI Error: $e");
      return "Executive summary unavailable at this time.";
    }
  }

Future<void> _generateAndDownloadPdf() async {
    setState(() => _isGeneratingReport = true);

    // 1. Get AI Text
    final aiSummary = await _generateAIInsight();

    // 2. Calculate "AI" Performance Score (0 to 10 scale)
    double calculatedScore = 5.0 + (totalCompletedQuantity * 0.1) + ((restaurantsCount + ngosCount) * 0.2);
    if (calculatedScore > 10.0) calculatedScore = 10.0;
    final String scoreString = calculatedScore.toStringAsFixed(1);

    // 3. Prepare Chart Data
    // Ensure we strictly have 7 data points. If list is empty, fill with 0s.
    final List<int> chartData = _weeklyCounts.isEmpty ? List.filled(7, 0) : _weeklyCounts;
    final List<String> chartLabels = _weeklyLabels.isEmpty ? List.generate(7, (i) => "") : _weeklyLabels;
    
    final maxValue = chartData.reduce(max);
    final safeMax = maxValue == 0 ? 1 : maxValue;
    
    // Create chart grid steps
    final step1 = (safeMax / 2).round();
    final step2 = safeMax;

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    
    // Palette
    final primaryColor = PdfColors.orange800;
    final accentColor = PdfColors.teal800;
    final gridColor = PdfColors.grey300;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EXECUTIVE IMPACT REPORT', style: pw.TextStyle(font: bold, fontSize: 20, color: accentColor)),
                      pw.Text('Food4Need Admin System', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('PERFORMANCE', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white)),
                        pw.Text('$scoreString / 10.0', style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.white)),
                      ],
                    ),
                  )
                ],
              ),
              pw.Divider(color: primaryColor, thickness: 2),
              pw.SizedBox(height: 20),

              // --- AI SUMMARY ---
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border(left: pw.BorderSide(color: accentColor, width: 4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('AI EXECUTIVE SUMMARY', style: pw.TextStyle(font: bold, fontSize: 10, color: accentColor)),
                    pw.SizedBox(height: 5),
                    pw.Text(aiSummary, style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // --- ACCURATE CHART SECTION ---
              pw.Text('ACTIVITY TREND (7 DAYS)', style: pw.TextStyle(font: bold, fontSize: 12, color: accentColor)),
              pw.SizedBox(height: 10),
              
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Y-Axis Labels (Fixed width)
                  pw.Container(
                    width: 30, // Fixed width for alignment
                    height: 135, // Match chart height + label buffer
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('$step2', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)), 
                        pw.Text('$step1', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)), 
                        pw.Text('0', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),   
                        pw.SizedBox(height: 10), // Spacing for X-axis labels
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // The Chart Area
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        // The Graph Frame
                        pw.Container(
                          height: 120,
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              left: pw.BorderSide(color: PdfColors.grey400),
                              bottom: pw.BorderSide(color: PdfColors.grey400),
                            ),
                          ),
                          child: pw.Stack(
                            children: [
                              // Grid Lines
                              pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Divider(color: gridColor, thickness: 1, borderStyle: pw.BorderStyle.dashed),
                                  pw.Divider(color: gridColor, thickness: 1, borderStyle: pw.BorderStyle.dashed),
                                  pw.Container(),
                                ],
                              ),
                              // Bars Row (Using Expanded to ensure equal width)
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: List.generate(chartData.length, (i) {
                                  final value = chartData[i];
                                  final double barHeight = (value / safeMax) * 118;
                                  
                                  return pw.Expanded(
                                    child: pw.Column(
                                      mainAxisAlignment: pw.MainAxisAlignment.end,
                                      children: [
                                        // Value Label
                                        if (value > 0)
                                          pw.Text('$value', style: pw.TextStyle(fontSize: 8, color: PdfColors.black)),
                                        
                                        // The Bar (or flat line if 0)
                                        pw.Container(
                                          width: 15, // Fixed bar width
                                          height: value == 0 ? 1 : (barHeight < 2 ? 2 : barHeight),
                                          color: value == 0 ? PdfColors.grey300 : accentColor,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        
                        // X-Axis Labels (Must match the bars exactly)
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: List.generate(chartLabels.length, (i) {
                            return pw.Expanded(
                              child: pw.Center(
                                child: pw.Text(
                                  chartLabels[i].split('/')[0] + '/' + chartLabels[i].split('/')[1],
                                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // X-Axis Title
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text('Date (Day/Month)', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
                )
              ),

              pw.SizedBox(height: 30),

              // --- KEY METRICS ---
              pw.Text('KEY METRICS', style: pw.TextStyle(font: bold, fontSize: 12, color: accentColor)),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                headers: ['Metric Category', 'Measured Value'],
                data: [
                  ['Total Surplus Rescued', '$totalCompletedQuantity kg'],
                  ['Active Restaurants', '$restaurantsCount'],
                  ['Participating NGOs', '$ngosCount'],
                  ['Total Transactions (7d)', '${chartData.fold(0, (a, b) => a + b)}'],
                ],
                headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: accentColor),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
                border: pw.TableBorder.all(color: PdfColors.grey300),
                cellPadding: const pw.EdgeInsets.all(8),
              ),

              pw.Spacer(),
              
              // --- FOOTER ---
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Food4Need Sustainability Initiative', style: pw.TextStyle(font: bold, fontSize: 9)),
                      pw.Text('yoyohuazo1234@gmail.com', style: pw.TextStyle(font: font, fontSize: 9, color: primaryColor)),
                    ],
                  ),
                  pw.Text('Report Generated: ${DateTime.now().toString().substring(0, 16)}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    setState(() => _isGeneratingReport = false);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Food4Need_Executive_Report.pdf',
    );
  }

  // Permanently deletes a user document
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

  // Navigates to the detailed user list page
  void _openUserList(String role, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserListPage(role: role, title: title),
      ),
    );
  }

  // Refreshes the user list and statistics
  Future<void> _refreshUsers() async {
    await FirebaseFirestore.instance.collection('users').get();
    await _loadStats();
  }

  // Renders the main dashboard tab with statistics grid and charts
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
                      value:
                          _loadingStats ? '...' : restaurantsCount.toString(),
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
                      value:
                          _loadingStats
                              ? '...'
                              : activeDonationQuantity.toString(),
                      icon: Icons.hourglass_top,
                      color: const Color(0xfffff4e6),
                    ),
                    _statCard(
                      label: 'Comp. Don. Qty',
                      value:
                          _loadingStats
                              ? '...'
                              : totalCompletedQuantity.toString(),
                      icon: Icons.local_shipping,
                      color: const Color(0xffe9eef6),
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton.icon(
                onPressed: _isGeneratingReport ? null : _generateAndDownloadPdf,
                icon:
                    _isGeneratingReport
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isGeneratingReport
                      ? 'AI is writing report...'
                      : 'Generate AI Report (PDF)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffd4a373),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Renders the chart card with horizontal scrolling for monthly view
  Widget _buildChartCard() {
    // Determine which data to use based on view mode
    final is7Days = _chartView == '7days';
    List<int> chartCounts;
    List<String> chartLabels;

    if (is7Days) {
      chartCounts = _weeklyCounts;
      chartLabels = _weeklyLabels;
    } else {
      chartCounts = _dailyCountsForSelectedMonth;
      chartLabels = _dailyLabelsForSelectedMonth;
    }

    final maxYValue =
        chartCounts.isEmpty ? 0 : chartCounts.fold<int>(0, (a, b) => max(a, b));
    final maxY = max(1, maxYValue);
    final interval = max(1, (maxY / 4).ceil());

    // Prepare Spots for LineChart (7 days)
    final spots = List.generate(
      chartCounts.length,
      (i) => FlSpot(i.toDouble(), chartCounts[i].toDouble()),
    );

    // Calculate width for horizontal scrolling
    final double chartWidth =
        is7Days
            ? MediaQuery.of(context).size.width - 60
            : max(
              MediaQuery.of(context).size.width - 60,
              chartCounts.length * 35.0,
            );

    // --- Logic for available months ---
    List<int> availableMonths = [];
    if (_selectedYear == 2025) {
      availableMonths = [12];
    } else {
      availableMonths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    }

    if (!availableMonths.contains(_selectedMonth)) {
      // Do nothing in build, but UI will restrict choices
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Row: Title and Main Dropdown ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  is7Days
                      ? 'Claimed — 7 Days'
                      : 'Claimed — $_selectedMonth/$_selectedYear',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: _chartView,
                  borderRadius: BorderRadius.circular(8),
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: '7days',
                      child: Text('Last 7 Days'),
                    ),
                    DropdownMenuItem(value: 'month', child: Text('By Month')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _chartView = v);
                      // If switching to month, reload to get specific month data
                      if (v == 'month') _loadStats();
                    }
                  },
                ),
              ],
            ),

            // --- Sub-Header Row: Year/Month Selectors (Visible only in Month View) ---
            if (!is7Days) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text("Year: ", style: TextStyle(fontSize: 12)),
                  DropdownButton<int>(
                    value: _selectedYear,
                    isDense: true,
                    // Start from 2025
                    items:
                        [2025, 2026, 2027, 2028].map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedYear = val;
                          // If switching to 2025, force month to Dec if currently < 12
                          if (_selectedYear == 2025) {
                            _selectedMonth = 12;
                          } else {
                            _selectedMonth = 1;
                          }
                        });
                        _loadStats();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text("Month: ", style: TextStyle(fontSize: 12)),
                  DropdownButton<int>(
                    value: _selectedMonth,
                    isDense: true,
                    // Only show valid months based on year
                    items:
                        availableMonths.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(m.toString()),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMonth = val);
                        _loadStats();
                      }
                    },
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // --- Scrollable Chart Area ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: 220,
                child: (is7Days
                    ? LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (chartCounts.length - 1).toDouble(),
                        minY: 0,
                        maxY: (maxY + interval).toDouble(),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (spot) => Colors.blueGrey,
                            getTooltipItems: (
                              List<LineBarSpot> touchedBarSpots,
                            ) {
                              return touchedBarSpots.map((barSpot) {
                                return LineTooltipItem(
                                  barSpot.y.toInt().toString(),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval.toDouble(),
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey.withOpacity(0.15),
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= chartLabels.length)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    chartLabels[idx],
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
                    )
                    : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (maxY + interval).toDouble(),
                        minY: 0,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            // <--- CHANGED: Shows UP (so not blocked by finger) but fits vertically
                            direction: TooltipDirection.top,
                            fitInsideVertically: true, 
                            fitInsideHorizontally: true,
                            getTooltipColor: (group) => Colors.blueGrey,
                            tooltipPadding: const EdgeInsets.all(8),
                            getTooltipItem: (
                              group,
                              groupIndex,
                              rod,
                              rodIndex,
                            ) {
                              return BarTooltipItem(
                                rod.toY.toInt().toString(),
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: interval.toDouble(),
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 1, // Show every day label
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= chartLabels.length)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    chartLabels[idx].split('/')[0],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval.toDouble(),
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey.withOpacity(0.15),
                                strokeWidth: 1,
                              ),
                        ),
                        barGroups: List.generate(
                          chartCounts.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: chartCounts[i].toDouble(),
                                color: Colors.green.shade600,
                                width: 12,
                                borderRadius: BorderRadius.circular(4),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: (maxY + interval).toDouble(),
                                  color: Colors.green.shade100.withOpacity(0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Total claimed items shown: ${chartCounts.fold<int>(0, (a, b) => a + b)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Expired vs Claimed (total)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child:
                  (totalCompletedQuantity == 0 && expiredDonationQuantity == 0)
                      ? Center(
                        child: Text(
                          _loadingStats
                              ? 'Loading pie chart...'
                              : 'No expired or claimed data',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 28,
                                sections: [
                                  PieChartSectionData(
                                    value: totalCompletedQuantity.toDouble(),
                                    color: Colors.green.shade600,
                                    title: 'Claimed\n$totalCompletedQuantity',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: expiredDonationQuantity.toDouble(),
                                    color: Colors.red.shade400,
                                    title: 'Expired\n$expiredDonationQuantity',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Claimed'),
                                ],
                              ),
                              const SizedBox(width: 18),
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Expired'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable widget for top statistics cards
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

  // Renders the User Verification tab with filtering and approval actions
  Widget _buildUserVerification() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Error loading users'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs =
            snap.data!.docs
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

        final filtered =
            docs.where((m) {
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
                children:
                    _userFilterLabels.entries.map((e) {
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
              child:
                  filtered.isEmpty
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
                                        onPressed:
                                            () => _approveUser(
                                              u['id'],
                                              u['email'] ?? '',
                                              u['name'] ?? 'User',
                                            ),
                                        child: const Text('Approve'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => _confirmDeleteDialog(u['id']),
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
                                        itemBuilder:
                                            (_) => const [
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
                                        onPressed:
                                            () => _confirmDeleteDialog(u['id']),
                                      ),
                                    ],
                                  ],
                                ),
                                leading: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => AdminUserProfilePage(
                                              userId: u['id'],
                                            ),
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

  // Main scaffold with Drawer navigation and body switching
  @override
  Widget build(BuildContext context) {
    final title =
        _selectedIndex == 0 ? 'Admin — Home' : 'Admin — User Verification';
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