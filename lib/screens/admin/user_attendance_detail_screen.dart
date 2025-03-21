import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_service.dart';
import '../../services/leave_request_service.dart';
import '../../services/organisation_service.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/branch_model.dart';

class UserAttendanceDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserAttendanceDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserAttendanceDetailScreen> createState() =>
      _UserAttendanceDetailScreenState();
}

class _UserAttendanceDetailScreenState
    extends State<UserAttendanceDetailScreen> {
  /// Maps each date to a list of events (AttendanceModel or LeaveRequestModel).
  Map<DateTime, List<dynamic>> _events = {};

  /// Current focus and selection in the TableCalendar.
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Shows a spinner while we fetch user data / attendance / leaves.
  bool _isLoading = true;

  /// If you add operations like “Delete record,” set this to true to show an overlay spinner.
  bool _isOperationInProgress = false;

  /// The user’s branch, used to check clock-in times and buffer.
  BranchModel? _userBranch;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  /// Normalizes a DateTime by stripping out hour/min/sec for a day-based key.
  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Checks if two DateTimes refer to the same calendar day.
  bool _isSameCalendarDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  /// Fetches branch info, attendance records, and approved leave events, then populates _events.
  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    final attendanceService =
        Provider.of<AttendanceService>(context, listen: false);
    final leaveRequestService =
        Provider.of<LeaveRequestService>(context, listen: false);
    final organisationService =
        Provider.of<OrganisationService>(context, listen: false);

    try {
      // 1) Fetch user doc to get branchId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final branchId = userDoc.data()?['branchId'] as String?;
      if (branchId == null || branchId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User branch not set.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2) Fetch branch info
      _userBranch = await organisationService.getBranchById(branchId);
      if (_userBranch == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch not found.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 3) Fetch attendance and leave records
      final attendanceRecords =
          await attendanceService.getUserAttendanceRecords(widget.userId);
      final leaveRecords = await leaveRequestService
          .getApprovedLeaveRequestsForUser(widget.userId);

      // 4) Combine them into a map of date -> [attendance, leaves]
      final Map<DateTime, List<dynamic>> events = {};

      // Attendance
      for (var record in attendanceRecords) {
        final date = _normalizeDate(record.clockIn.toDate());
        events.putIfAbsent(date, () => []).add(record);
      }

      // Approved leaves
      for (var leave in leaveRecords) {
        final start = _normalizeDate(leave.startDate.toDate());
        final end = _normalizeDate(leave.endDate.toDate());
        for (DateTime day = start;
            !day.isAfter(end);
            day = day.add(const Duration(days: 1))) {
          events.putIfAbsent(day, () => []).add(leave);
        }
      }

      setState(() {
        _events = events;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load attendance and leave data.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// (Optional) If you want the user to pull-to-refresh the data
  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    try {
      await _loadEvents();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Returns events for the given day, or an empty list if none.
  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _events[normalizedDay] ?? [];
  }

  /// Decide a single day status: 'leave' > 'late' > 'present' > 'absent', or 'none' if future day w/o events
  String _getDayStatus(DateTime date, List<dynamic> events) {
    final dayKey = _normalizeDate(date);
    final todayKey = _normalizeDate(DateTime.now());

    // If any event is a leave => 'leave'
    if (events.any((e) => e is LeaveRequestModel)) {
      return 'leave';
    }

    // If date is after today and no events => 'none'
    if (dayKey.isAfter(todayKey) && events.isEmpty) {
      return 'none';
    }

    // Check earliest attendance
    AttendanceModel? earliestRecord;
    for (var event in events) {
      if (event is AttendanceModel) {
        if (earliestRecord == null ||
            event.clockIn.toDate().isBefore(earliestRecord.clockIn.toDate())) {
          earliestRecord = event;
        }
      }
    }

    // If no attendance => 'absent'
    if (earliestRecord == null) {
      return 'absent';
    }

    // Check if user is late
    final clockInTime = earliestRecord.clockIn.toDate();
    final actualClockInMinutes = clockInTime.hour * 60 + clockInTime.minute;

    final branchClockInMinutes = _userBranch?.clockInMinutes ?? 540;
    final bufferMinutes = _userBranch?.bufferMinutes ?? 0;
    final allowedClockInMinutes = branchClockInMinutes + bufferMinutes;

    if (actualClockInMinutes > allowedClockInMinutes) {
      return 'late';
    }
    return 'present';
  }

  /// Core UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.userName}'s Attendance"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMainContent(),
          ),
          if (_isOperationInProgress)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the main content once data is loaded
  Widget _buildMainContent() {
    return Column(
      children: [
        _buildCalendar(),
        _buildLegend(),
        Expanded(
          child: _selectedDay == null
              ? const Center(
                  child: Text(
                    'Select a day to see attendance and leave details.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : _buildDayDetails(),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) =>
            _isSameCalendarDay(_selectedDay ?? DateTime.now(), day),
        eventLoader: _getEventsForDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
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
          markerBuilder: (context, date, events) {
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
          selectedBuilder: (context, date, events) {
            return Container(
              margin: const EdgeInsets.all(4.0),
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
          todayBuilder: (context, date, events) {
            return Container(
              margin: const EdgeInsets.all(4.0),
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
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        children: [
          _buildLegendMarker(Colors.green, 'Present'),
          _buildLegendMarker(Colors.orange, 'Late'),
          _buildLegendMarker(Colors.red, 'Absent'),
          _buildLegendMarker(Colors.blue, 'On Leave'),
        ],
      ),
    );
  }

  Widget _buildLegendMarker(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  Widget _buildDayDetails() {
    final dayEvents = _getEventsForDay(_selectedDay!);

    // Separate attendance from leave
    final attendanceList = <AttendanceModel>[];
    final leaveList = <LeaveRequestModel>[];
    for (var e in dayEvents) {
      if (e is AttendanceModel) {
        attendanceList.add(e);
      } else if (e is LeaveRequestModel) {
        leaveList.add(e);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date display
          Center(
            child: Text(
              DateFormat.yMMMMd().format(_selectedDay!),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Attendance
          if (attendanceList.isNotEmpty) ...[
            const Text(
              'Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            for (var record in attendanceList) _buildAttendanceCard(record),
          ],

          if (attendanceList.isNotEmpty && leaveList.isNotEmpty)
            const Divider(height: 32, thickness: 1),

          // Leave
          if (leaveList.isNotEmpty) ...[
            const Text(
              'Approved Leave',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            for (var leave in leaveList) _buildLeaveCard(leave),
          ],

          // No events
          if (attendanceList.isEmpty && leaveList.isEmpty)
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
    final duration = _calcDuration(record);
    final clockInTime = record.clockIn.toDate();
    final clockInStr = _fmtTimestamp(record.clockIn);
    var clockOutStr =
        record.clockOut == null ? 'N/A' : _fmtTimestamp(record.clockOut);

    bool differentDay = false;
    if (record.clockOut != null) {
      final outDate = record.clockOut!.toDate();
      differentDay = !_isSameCalendarDay(clockInTime, outDate);
      if (differentDay) {
        clockOutStr += ' (Different Day)';
      }
    }

    // Check if user is late
    bool isLate = false;
    if (_userBranch != null) {
      final actualClockInMinutes = clockInTime.hour * 60 + clockInTime.minute;
      final branchClockInMinutes = _userBranch!.clockInMinutes;
      final bufferMinutes = _userBranch!.bufferMinutes;
      final allowedClockInMinutes = branchClockInMinutes + bufferMinutes;
      isLate = actualClockInMinutes > allowedClockInMinutes;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
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
            Text('Clock Out: $clockOutStr'),
            const SizedBox(height: 4),
            Text(
              'Duration: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestModel leave) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.beach_access, color: Colors.blue, size: 30),
        title: Text(
          '${leave.leaveType} (${leave.dayType})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${_fmtDate(leave.startDate)} '
              'To: ${_fmtDate(leave.endDate)}',
            ),
            const SizedBox(height: 4),
            Text('Reason: ${leave.reason}'),
            const SizedBox(height: 4),
            Text('Status: ${leave.status}'),
          ],
        ),
      ),
    );
  }

  // The methods below are renamed to avoid collisions and are used within the code:

  Duration _calcDuration(AttendanceModel record) {
    if (record.clockOut != null) {
      return record.clockOut!.toDate().difference(record.clockIn.toDate());
    }
    return Duration.zero;
  }

  String _fmtTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('yyyy-MM-dd hh:mm a').format(ts.toDate());
  }

  String _fmtDate(Timestamp ts) {
    return DateFormat.yMMMMd().format(ts.toDate());
  }
}
