import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:z_emp/screens/common/user_todo_task_list_screen.dart';
import 'package:z_emp/screens/sales_staff/enquiry_list_screen.dart';
import 'package:z_emp/screens/sales_staff/job_enquiry_screen.dart';
import 'package:z_emp/screens/sales_staff/sales_data_entry_screen.dart';
import 'package:z_emp/screens/sales_staff/sales_order_history_screen.dart';
import '../../widgets/profile_section.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/announcement_card.dart';
import '../../widgets/clock_in_out_button.dart';
import 'task_logging_screen.dart';
import '../common/leave_request_form.dart';
import '../common/salary_advance_screen.dart';
import '../../providers/announcement_provider.dart';
import 'package:z_emp/screens/common/attendance_history_screen.dart';
// NEW: Import the performance analytics card
import '../../widgets/performance_analytics_card.dart';

class MeasurementDashboardContent extends StatefulWidget {
  const MeasurementDashboardContent({super.key});

  @override
  State<MeasurementDashboardContent> createState() =>
      _MeasurementDashboardContentState();
}

class _MeasurementDashboardContentState
    extends State<MeasurementDashboardContent> {
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _dashboardItems = [
    {
      'title': 'Log Task',
      'icon': Icons.task_alt,
      'color': Colors.deepPurple,
      'screen': const TaskLoggingScreen(),
    },
    {
      'title': 'To-do List',
      'icon': Icons.work_outline,
      'color': Colors.deepPurple,
      'screen': const UserTodoTaskListScreen(),
    },
    {
      'title': 'Job Enquiries',
      'icon': Icons.work_outline,
      'color': Colors.deepPurple,
      'screen': const JobEnquiryScreen(),
    },
    {
      'title': 'Enquiry List',
      'icon': Icons.follow_the_signs,
      'color': Colors.indigo,
      'screen': const EnquiryListScreen(),
    },
    {
      'title': 'Sales Data Entry',
      'icon': Icons.edit_note,
      'color': Colors.teal,
      'screen': const SalesDataEntryScreen(),
    },
    {
      'title': 'Enquiry History',
      'icon': Icons.storage_rounded,
      'color': Colors.brown,
      'screen': const SalesOrderHistoryScreen(),
    },
    {
      'title': 'Leave Requests',
      'icon': Icons.time_to_leave,
      'color': Colors.indigo,
      'screen': const LeaveRequestForm(),
    },
    {
      'title': 'Salary Advance',
      'icon': Icons.attach_money,
      'color': Colors.teal,
      'screen': const SalaryAdvanceScreen(),
    },
    {
      'title': 'Attendance',
      'icon': Icons.access_time,
      'color': Colors.blueGrey,
      'screen': const AttendanceHistoryScreen(),
    },
  ];

  Future<void> _handleRefresh() async {
    await Provider.of<AnnouncementProvider>(context, listen: false)
        .fetchAnnouncements();
    // Refresh other data if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Same gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color.fromARGB(255, 49, 108, 196),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const ProfileSection(),
            const AnnouncementCard(role: "measurement"),
            const ClockInOutButton(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Page 1: Dashboard tiles grid
                    GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _dashboardItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemBuilder: (context, index) {
                        final item = _dashboardItems[index];
                        return DashboardTile(
                          title: item['title'],
                          icon: item['icon'],
                          color: item['color'],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => item['screen']),
                          ),
                        );
                      },
                    ),
                    // Page 2: Performance Analytics card
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: const PerformanceAnalyticsCard(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
