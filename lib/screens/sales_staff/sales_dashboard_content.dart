import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:z_emp/screens/admin/product_list_screen.dart';
import 'package:z_emp/screens/common/attendance_history_screen.dart';
import 'package:z_emp/screens/common/customer_details_screen.dart';
import 'package:z_emp/screens/common/user_todo_task_list_screen.dart';
import 'package:z_emp/screens/sales_staff/sales_order_history_screen.dart';
import 'package:z_emp/screens/sales_staff/sales_records_screen.dart';
import '../../widgets/profile_section.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/announcement_card.dart';
import '../../widgets/clock_in_out_button.dart';
import 'job_enquiry_screen.dart';
import 'enquiry_list_screen.dart';
import 'sales_data_entry_screen.dart';
import '../common/leave_request_form.dart';
import '../common/salary_advance_screen.dart';
import '../../providers/announcement_provider.dart';
// NEW: Import the performance analytics card
import '../../widgets/performance_analytics_card.dart';

class SalesDashboardContent extends StatefulWidget {
  const SalesDashboardContent({super.key});

  @override
  State<SalesDashboardContent> createState() => _SalesDashboardContentState();
}

class _SalesDashboardContentState extends State<SalesDashboardContent> {
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _dashboardItems = [
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
      'title': 'Enquiry History',
      'icon': Icons.storage_rounded,
      'color': Colors.brown,
      'screen': const SalesOrderHistoryScreen(),
    },
    {
      'title': 'Sales Data Entry',
      'icon': Icons.edit_note,
      'color': Colors.teal,
      'screen': const SalesDataEntryScreen(),
    },
    {
      'title': 'Sales Records',
      'icon': Icons.list_alt,
      'color': Colors.blue,
      'screen': const SalesRecordsScreen(),
    },
    {
      'title': 'Leave Requests',
      'icon': Icons.time_to_leave,
      'color': Colors.orange,
      'screen': const LeaveRequestForm(),
    },
    {
      'title': 'Salary Advance',
      'icon': Icons.attach_money,
      'color': Colors.green,
      'screen': const SalaryAdvanceScreen(),
    },
    {
      'title': 'To-do List',
      'icon': Icons.work_outline,
      'color': Colors.deepPurple,
      'screen': const UserTodoTaskListScreen(),
    },
    {
      'title': 'Attendance',
      'icon': Icons.access_time,
      'color': Colors.redAccent,
      'screen': const AttendanceHistoryScreen(),
    },
    {
      'title': 'Products',
      'icon': Icons.store,
      'color': Colors.cyan,
      'screen': const ProductListScreen(),
    },
    {
      'title': 'Customers List',
      'icon': Icons.list_alt,
      'color': Colors.blueGrey,
      'screen': const CustomerListScreen(),
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
        // Gradient background
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
            // Top sections
            const ProfileSection(),
            const AnnouncementCard(role: "sales"),
            const ClockInOutButton(),
            Expanded(
              // Instead of a single RefreshIndicator around the PageView,
              // give each page its own RefreshIndicator + scrollable widget.
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                children: [
                  // PAGE 1: Dashboard grid
                  RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                    ),
                  ),
                  // PAGE 2: Performance Analytics
                  RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: const PerformanceAnalyticsCard(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
