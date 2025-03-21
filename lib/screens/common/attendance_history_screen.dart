import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_service.dart';
import '../../services/organisation_service.dart';
// Remove this import if your app doesn't handle leaves
import '../../services/leave_request_service.dart';

import '../../models/attendance_model.dart';
// Remove this import if your app doesn't handle leaves
import '../../models/leave_request_model.dart';
import '../../models/branch_model.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  /// Events for each day, combining attendance and leave.
  final Map<DateTime, List<dynamic>> _events = {};

  /// Currently focused day in the calendar
  DateTime _focusedDay = DateTime.now();

  /// The user's selected day
  DateTime? _selectedDay;

  /// Loading state for initial fetch
  bool _isLoading = true;

  /// Holds any error message that may occur
  String? _error;

  /// We fetch the user's branch to check lateness
  BranchModel? _userBranch;

  @override
  void initState() {
    super.initState();
    _loadUserAttendanceData();
  }

  /// Normalizes a date to remove hours/minutes/seconds
  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  /// Main method to fetch attendance records (and leaves, if used) plus branch info
  Future<void> _loadUserAttendanceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Identify the user
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No user is currently logged in.';
      });
      return;
    }

    try {
      final attendanceService =
          Provider.of<AttendanceService>(context, listen: false);
      final organisationService =
          Provider.of<OrganisationService>(context, listen: false);
      // Remove this if your app doesn't handle leaves
      final leaveRequestService =
          Provider.of<LeaveRequestService>(context, listen: false);

      // 1) Get user doc for branchId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _error = 'User document not found.';
        });
        return;
      }

      final data = userDoc.data();
      final branchId = data?['branchId'] as String?;
      if (branchId == null || branchId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'User has no assigned branch.';
        });
        return;
      }

      // 2) Fetch branch
      _userBranch = await organisationService.getBranchById(branchId);
      if (_userBranch == null) {
        setState(() {
          _isLoading = false;
          _error = 'Branch not found or no branch data.';
        });
        return;
      }

      // 3) Fetch attendance
      final allAttendance =
          await attendanceService.getUserAttendanceRecords(userId);

      // 4) (Optional) fetch leaves
      final approvedLeaves =
          await leaveRequestService.getApprovedLeaveRequestsForUser(userId);

      // 5) Build the events map
      final Map<DateTime, List<dynamic>> tempEvents = {};

      // Populate attendance
      for (var record in allAttendance) {
        final day = _normalizeDate(record.clockIn.toDate());
        tempEvents.putIfAbsent(day, () => []).add(record);
      }

      // Populate leaves
      for (var leave in approvedLeaves) {
        final start = _normalizeDate(leave.startDate.toDate());
        final end = _normalizeDate(leave.endDate.toDate());
        for (DateTime d = start;
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))) {
          tempEvents.putIfAbsent(d, () => []).add(leave);
        }
      }

      setState(() {
        _events.clear();
        _events.addAll(tempEvents);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading attendance data: $e';
      });
    }
  }

  /// Return all events for a specific day
  List<dynamic> _getEventsForDay(DateTime day) {
    final normalized = _normalizeDate(day);
    return _events[normalized] ?? [];
  }

  /// Decide day status: 'leave', 'none' (future w/o events), 'absent', 'late', or 'present'
  String _getDayStatus(DateTime date, List<dynamic> events) {
    final normalized = _normalizeDate(date);
    final today = _normalizeDate(DateTime.now());

    // If there's a leave
    if (events.any((e) => e is LeaveRequestModel)) {
      return 'leave';
    }

    // Future day with no events
    if (normalized.isAfter(today) && events.isEmpty) {
      return 'none';
    }

    // Check earliest attendance
    AttendanceModel? earliest;
    for (var e in events) {
      if (e is AttendanceModel) {
        if (earliest == null ||
            e.clockIn.toDate().isBefore(earliest.clockIn.toDate())) {
          earliest = e;
        }
      }
    }

    if (earliest == null) {
      return 'absent';
    }

    // Check lateness
    final clockInTime = earliest.clockIn.toDate();
    final actual = clockInTime.hour * 60 + clockInTime.minute;
    final branchClockIn = _userBranch!.clockInMinutes;
    final buffer = _userBranch!.bufferMinutes;
    final allowed = branchClockIn + buffer;

    if (actual > allowed) {
      return 'late';
    }
    return 'present';
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final date = ts.toDate().toLocal();
    return DateFormat('yyyy-MM-dd hh:mm a').format(date);
  }

  /// Check if two dates are the same day
  bool _sameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  Duration _calculateDuration(AttendanceModel record) {
    if (record.clockOut != null) {
      final out = record.clockOut!.toDate();
      return out.difference(record.clockIn.toDate());
    }
    return Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance History'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    // The TableCalendar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: _buildCalendar(),
                    ),
                    // Legend row
                    _buildLegend(),
                    // Show day details
                    Expanded(
                      child: _selectedDay == null
                          ? const Center(
                              child: Text(
                                'Select a date to see details',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : _buildDayDetails(_selectedDay!),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) =>
          _selectedDay != null && _isSameDay(day, _selectedDay!),
      eventLoader: (day) => _getEventsForDay(day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (ctx, date, events) {
          final status = _getDayStatus(date, events);
          if (status == 'none') {
            return const SizedBox();
          }
          Color color;
          switch (status) {
            case 'present':
              color = Colors.green;
              break;
            case 'late':
              color = Colors.orange;
              break;
            case 'leave':
              color = Colors.blue;
              break;
            case 'absent':
            default:
              color = Colors.red;
              break;
          }
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
        selectedBuilder: (ctx, date, events) {
          return Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        todayBuilder: (ctx, date, events) {
          return Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        children: [
          _buildLegendMarker(Colors.green, 'Present'),
          _buildLegendMarker(Colors.orange, 'Late'),
          _buildLegendMarker(Colors.red, 'Absent'),
          _buildLegendMarker(Colors.blue, 'Leave'),
        ],
      ),
    );
  }

  Widget _buildLegendMarker(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _buildDayDetails(DateTime day) {
    final events = _getEventsForDay(day);

    // Separate attendance from leaves
    final attendanceEvents = <AttendanceModel>[];
    final leaveEvents = <LeaveRequestModel>[];

    for (var e in events) {
      if (e is AttendanceModel) {
        attendanceEvents.add(e);
      } else if (e is LeaveRequestModel) {
        leaveEvents.add(e);
      }
    }

    // Build the details
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day title
          Center(
            child: Text(
              DateFormat.yMMMMd().format(day),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Attendance
          if (attendanceEvents.isNotEmpty) ...[
            const Text(
              'Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...attendanceEvents.map(_buildAttendanceCard).toList(),
          ],
          // Divider if both attendance and leave are present
          if (attendanceEvents.isNotEmpty && leaveEvents.isNotEmpty)
            const Divider(height: 32, thickness: 1),
          // Leaves
          if (leaveEvents.isNotEmpty) ...[
            const Text(
              'Approved Leave',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...leaveEvents.map(_buildLeaveCard).toList(),
          ],
          // If none
          if (attendanceEvents.isEmpty && leaveEvents.isEmpty)
            const Center(
              child: Text(
                'No attendance or leave records for this day.',
                style: TextStyle(fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel record) {
    final clockInDate = record.clockIn.toDate().toLocal();
    final clockOutDate = record.clockOut?.toDate().toLocal();
    final clockInStr = _formatTimestamp(record.clockIn);
    final clockOutStr =
        clockOutDate == null ? 'N/A' : _formatTimestamp(record.clockOut);
    final differentDay =
        clockOutDate != null && !_sameDay(clockInDate, clockOutDate);
    final duration = _calculateDuration(record);

    // Check lateness
    final actualMinutes = clockInDate.hour * 60 + clockInDate.minute;
    final branchClockIn = _userBranch!.clockInMinutes;
    final buffer = _userBranch!.bufferMinutes;
    final allowed = branchClockIn + buffer;
    final isLate = actualMinutes > allowed;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isLate ? Icons.warning : Icons.check_circle,
          color: isLate ? Colors.orange : Colors.green,
          size: 30,
        ),
        title: Text(
          'Clock In: $clockInStr',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Clock Out: $clockOutStr${differentDay ? ' (Different Day)' : ''}'),
            const SizedBox(height: 4),
            Text(
              'Duration: ${duration.inHours}h ${duration.inMinutes % 60}m',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestModel leave) {
    final start =
        DateFormat.yMMMMd().format(leave.startDate.toDate().toLocal());
    final end = DateFormat.yMMMMd().format(leave.endDate.toDate().toLocal());
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.beach_access, color: Colors.blue, size: 30),
        title: Text(
          '${leave.leaveType} (${leave.dayType})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: $start  To: $end'),
            const SizedBox(height: 4),
            Text('Reason: ${leave.reason}'),
            const SizedBox(height: 4),
            Text('Status: ${leave.status}'),
          ],
        ),
      ),
    );
  }
}
