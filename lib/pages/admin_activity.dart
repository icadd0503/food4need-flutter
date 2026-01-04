import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminActivityPage extends StatefulWidget {
  const AdminActivityPage({super.key});

  @override
  State<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends State<AdminActivityPage> {
  // Caching mechanism to store user names to minimize repeated Firestore reads,
  // and state variables for the current filter selections.
  final Map<String, String> _nameCache = {};
  String _timeFilter = '7d';
  String _typeFilter = 'all';

  final Map<String, String> _timeFilterLabels = {
    'all': 'All time',
    '24h': 'Last 24h',
    '7d': 'Last 7d',
    '30d': 'Last 30d'
  };
  final Map<String, String> _typeFilterLabels = {
    'all': 'All',
    'userRegistered': 'Registrations',
    'posted': 'Posted',
    'reserved': 'Reserved',
    'claimed': 'Claimed',
    'completed': 'Completed',
  };

  // Helper functions to fetch and cache user names (restaurants/NGOs) efficiently.
  // This prevents making a network request every time a row is rendered.
  Future<String> _getUserName(String id) async {
    if (_nameCache.containsKey(id)) return _nameCache[id]!;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(id).get();
    final data = doc.data() as Map<String, dynamic>?;
    final name = (data?['name'] ?? data?['email'] ?? id).toString();
    _nameCache[id] = name;
    return name;
  }

  Future<void> _prefetchNames(Set<String> ids) async {
    final toFetch = ids.where((i) => !_nameCache.containsKey(i)).toList();
    if (toFetch.isEmpty) return;
    final batch = FirebaseFirestore.instance.collection('users');
    for (final id in toFetch) {
      try {
        final doc = await batch.doc(id).get();
        final d = doc.data() as Map<String, dynamic>?;
        _nameCache[id] = (d?['name'] ?? d?['email'] ?? id).toString();
      } catch (_) {
        _nameCache[id] = id;
      }
    }
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // Core logic: Aggregates raw data from 'users' and 'donations' collections into
  // a unified list of activity events (registrations, claims, posts) and resolves IDs to names.
  Future<List<_ActivityItem>> _prepareEvents(
      QuerySnapshot donationsSnap, QuerySnapshot usersSnap) async {
    final List<_ActivityItem> events = [];
    final Set<String> idsToResolve = {};

    for (final u in usersSnap.docs) {
      final data = u.data() as Map<String, dynamic>? ?? {};
      final created = data['createdAt'] as Timestamp?;
      if (created != null) {
        final role = (data['role'] ?? 'user').toString();
        final id = u.id;
        idsToResolve.add(id);
        events.add(_ActivityItem(
          time: created.toDate(),
          type: _ActivityType.userRegistered,
          primaryId: id,
          details: {'role': role},
        ));
      }
    }

    for (final d in donationsSnap.docs) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final title =
          (data['title'] ?? data['details'] ?? 'Donation').toString();
      final qty = (data['quantity'] ?? '').toString();
      final donationId = d.id;

      final createdAt = data['createdAt'] as Timestamp?;
      final restId = data['restaurantId']?.toString();
      if (createdAt != null) {
        if (restId != null && restId.isNotEmpty) idsToResolve.add(restId);
        events.add(_ActivityItem(
          time: createdAt.toDate(),
          type: _ActivityType.posted,
          primaryId: restId,
          details: {'donationId': donationId, 'title': title, 'qty': qty},
        ));
      }

      final claimedAt = data['claimedAt'] as Timestamp?;
      final claimedBy = data['claimedBy']?.toString() ??
          data['receiverId']?.toString() ??
          data['reservedNgoId']?.toString();
      if (claimedAt != null) {
        if (claimedBy != null && claimedBy.isNotEmpty)
          idsToResolve.add(claimedBy);
        events.add(_ActivityItem(
          time: claimedAt.toDate(),
          type: _ActivityType.claimed,
          primaryId: claimedBy,
          details: {'donationId': donationId, 'title': title, 'qty': qty},
        ));
      }

      final completedAt = data['completedAt'] as Timestamp?;
      final completedBy = claimedBy;
      if (completedAt != null) {
        if (completedBy != null && completedBy.isNotEmpty)
          idsToResolve.add(completedBy);
        events.add(_ActivityItem(
          time: completedAt.toDate(),
          type: _ActivityType.completed,
          primaryId: completedBy,
          details: {'donationId': donationId, 'title': title, 'qty': qty},
        ));
      }

      final resHist = data['reservationHistory'];
      if (resHist is List) {
        for (final e in resHist) {
          if (e is Map) {
            final ngoId =
                (e['ngoId'] ?? e['reservedNgoId'] ?? e['id'])?.toString();
            final ts =
                (e['createdAt'] ?? e['at'] ?? e['timestamp']) as Timestamp?;
            if (ngoId != null && ngoId.isNotEmpty && ts != null) {
              idsToResolve.add(ngoId);
              events.add(_ActivityItem(
                time: ts.toDate(),
                type: _ActivityType.reserved,
                primaryId: ngoId,
                details: {
                  'donationId': donationId,
                  'title': title,
                  'qty': qty
                },
              ));
            }
          }
        }
      }
    }

    await _prefetchNames(idsToResolve);

    final resolved = events.map((e) {
      String text;
      switch (e.type) {
        case _ActivityType.userRegistered:
          final role = e.details?['role'] ?? 'user';
          final name =
              _nameCache[e.primaryId ?? ''] ?? e.primaryId ?? 'Unknown';
          text = 'New ${role.toString().toUpperCase()}: $name';
          break;
        case _ActivityType.posted:
          final rest = e.primaryId != null
              ? (_nameCache[e.primaryId!] ?? e.primaryId!)
              : 'Unknown restaurant';
          text =
              '$rest posted donation "${e.details?['title']}" (${e.details?['qty'] ?? '-'})';
          break;
        case _ActivityType.claimed:
          final ngo = e.primaryId != null
              ? (_nameCache[e.primaryId!] ?? e.primaryId!)
              : 'Unknown NGO';
          text =
              '$ngo claimed donation "${e.details?['title']}" (${e.details?['qty'] ?? '-'})';
          break;
        case _ActivityType.completed:
          final ngo = e.primaryId != null
              ? (_nameCache[e.primaryId!] ?? e.primaryId!)
              : 'Unknown NGO';
          text = 'Donation "${e.details?['title']}" completed by $ngo';
          break;
        case _ActivityType.reserved:
          final ngo = e.primaryId != null
              ? (_nameCache[e.primaryId!] ?? e.primaryId!)
              : 'Unknown NGO';
          text =
              '$ngo reserved donation "${e.details?['title']}" (${e.details?['qty'] ?? '-'})';
          break;
      }
      return _ActivityItem(
          time: e.time,
          type: e.type,
          primaryId: e.primaryId,
          details: e.details,
          pretty: text);
    }).toList();

    resolved.sort((a, b) => b.time.compareTo(a.time));
    return resolved;
  }

  // Filtering logic to check if an activity item matches the selected Type and Time range.
  bool _typeMatchesFilter(_ActivityItem e) {
    if (_typeFilter == 'all') return true;
    switch (_typeFilter) {
      case 'userRegistered':
        return e.type == _ActivityType.userRegistered;
      case 'posted':
        return e.type == _ActivityType.posted;
      case 'reserved':
        return e.type == _ActivityType.reserved;
      case 'claimed':
        return e.type == _ActivityType.claimed;
      case 'completed':
        return e.type == _ActivityType.completed;
      default:
        return true;
    }
  }

  bool _timeMatchesFilter(_ActivityItem e) {
    if (_timeFilter == 'all') return true;
    final now = DateTime.now();
    DateTime cutoff;
    switch (_timeFilter) {
      case '24h':
        cutoff = now.subtract(const Duration(hours: 24));
        break;
      case '7d':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      default:
        return true;
    }
    return e.time.isAfter(cutoff);
  }

  // Renders the dropdown UI for selecting time and activity type filters.
  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _timeFilter,
                decoration:
                    const InputDecoration(labelText: 'Time', isDense: true),
                items: _timeFilterLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _timeFilter = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _typeFilter,
                decoration:
                    const InputDecoration(labelText: 'Type', isDense: true),
                items: _typeFilterLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _typeFilter = v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main build method: Uses nested StreamBuilders to listen to Donations and Users collections,
  // processes the data, applies filters, and renders the list of activities.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Recent Activity'),
          backgroundColor: const Color(0xffd4a373)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donations').snapshots(),
        builder: (context, donationsSnap) {
          if (donationsSnap.hasError)
            return const Center(child: Text('Error loading donations'));
          if (!donationsSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnap) {
              if (usersSnap.hasError)
                return const Center(child: Text('Error loading users'));
              if (!usersSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              return FutureBuilder<List<_ActivityItem>>(
                future:
                    _prepareEvents(donationsSnap.data!, usersSnap.data!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snap.hasError)
                    return Center(
                        child: Text(
                            'Failed to prepare activity: ${snap.error}'));
                  final events = snap.data ?? [];
                  // apply filters
                  final filtered = events
                      .where((e) =>
                          _typeMatchesFilter(e) && _timeMatchesFilter(e))
                      .toList();
                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                        setState(() {});
                      },
                      child: ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _buildFilterBar(),
                          ),
                          const SizedBox(height: 32),
                          Center(
                              child: Text(_timeFilter == 'all' &&
                                      _typeFilter == 'all'
                                  ? 'No recent activity'
                                  : 'No activity for selected filters')),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 300));
                      setState(() {});
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: _buildFilterBar(),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final ev = filtered[i];
                              final icon = _iconForType(ev.type);
                              return ListTile(
                                leading: CircleAvatar(
                                    backgroundColor:
                                        icon.color.withOpacity(0.1),
                                    child: Icon(icon.icon,
                                        color: icon.color)),
                                title: Text(ev.pretty ?? ''),
                                subtitle: Text(_fmtDate(ev.time)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Returns specific icon and color styling for each activity type.
  _IconPair _iconForType(_ActivityType t) {
    switch (t) {
      case _ActivityType.userRegistered:
        return _IconPair(Icons.person_add, Colors.blue);
      case _ActivityType.posted:
        return _IconPair(Icons.restaurant, Colors.orange);
      case _ActivityType.claimed:
        return _IconPair(Icons.how_to_reg, Colors.purple);
      case _ActivityType.completed:
        return _IconPair(Icons.check_circle, Colors.green);
      case _ActivityType.reserved:
        return _IconPair(Icons.bookmark, Colors.teal);
    }
  }
}

// Data models and enums to represent activity events and visual properties.
class _ActivityItem {
  final DateTime time;
  final _ActivityType type;
  final String? primaryId;
  final Map<String, dynamic>? details;
  final String? pretty;

  _ActivityItem(
      {required this.time,
      required this.type,
      this.primaryId,
      this.details,
      this.pretty});
}

enum _ActivityType { userRegistered, posted, reserved, claimed, completed }

class _IconPair {
  final IconData icon;
  final Color color;
  _IconPair(this.icon, this.color);
}