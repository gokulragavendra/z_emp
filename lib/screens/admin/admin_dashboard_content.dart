import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:z_emp/screens/admin/admin_todo_task_history_screen.dart';
import 'package:z_emp/widgets/overview_card.dart';
import '../../l10n/app_localizations.dart';

// Give each import its own prefix if there's any possibility of naming conflicts.
import 'admin_todo_task_assignment_screen.dart' as todo_assignment;
import 'admin_todo_task_list_screen.dart' as todo_list;
import 'announcement_management_screen.dart' as announcement_screen;
import 'user_management_screen.dart' as user_screen;
import 'enquiry_management_screen.dart' as enquiry_screen;
import 'leave_management_screen.dart' as leave_screen;
import 'salary_advance_management_screen.dart' as salary_screen;
import 'attendance_overview_screen.dart' as attendance_screen;
import 'report_generation_screen.dart' as report_screen;
import 'organisation_management_screen.dart' as org_screen;
import 'product_management_screen.dart' as product_manage_screen;
import 'product_list_screen.dart' as product_list_screen;
import 'geo_fence_management_screen.dart' as geo_screen;
import '../common/customer_details_screen.dart' as customer_screen;

import '../../providers/announcement_provider.dart';
import '../../widgets/profile_section.dart';
import '../../widgets/announcement_card.dart';
import '../../widgets/dashboard_tile.dart';

class AdminDashboardContent extends StatefulWidget {
  const AdminDashboardContent({super.key});

  @override
  State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent> {
  final PageController _pageController = PageController();

  bool _isLoading = false; // Loading state to show/hide the loading indicator

  /// Pull-to-refresh operation, e.g. to fetch announcements or other data.
  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Provider.of<AnnouncementProvider>(context, listen: false)
          .fetchAnnouncements();
      // Add other refresh logic if needed.
    } catch (error) {
      // Handle any error that occurs during the fetch process
      if (mounted) {
        final localization = AppLocalizations.of(context)!;
        messenger.showSnackBar(
          SnackBar(
            content: Text(localization
                .translate('error_occurred')
                .replaceAll('{error}', error.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // If you need a confirmation dialog in the future for destructive actions,
  // here's an example (commented out):
  // Future<bool> _confirmAction(String actionName) async {
  //   return await showDialog<bool>(
  //         context: context,
  //         builder: (BuildContext dialogContext) {
  //           return AlertDialog(
  //             title: Text('Confirm $actionName'),
  //             content: Text('Are you sure you want to proceed?'),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(dialogContext).pop(false),
  //                 child: const Text('Cancel'),
  //               ),
  //               ElevatedButton(
  //                 onPressed: () => Navigator.of(dialogContext).pop(true),
  //                 child: const Text('Yes'),
  //               ),
  //             ],
  //           );
  //         },
  //       ) ??
  //       false;
  // }

  // Dashboard items will be created in the build method to access localization

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    // Create dashboard items with localized titles
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': localization.translate("todo"),
        'icon': Icons.task_rounded,
        'color': Colors.indigo,
        'screen': const todo_assignment.AdminTodoTaskAssignmentScreen(),
      },
      {
        'title': localization.translate("todo_list"),
        'icon': Icons.task_alt,
        'color': Colors.indigo,
        'screen': const todo_list.AdminTodoTaskListScreen(),
      },
      {
        'title': localization.translate("todo_history"),
        'icon': Icons.history,
        'color': Colors.indigo,
        'screen': const AdminTodoTaskHistoryScreen(),
      },
      {
        'title': localization.translate("enquiries"),
        'icon': Icons.question_answer,
        'color': Colors.purple,
        'screen': const enquiry_screen.EnquiryManagementScreen(),
      },
      {
        'title': localization.translate("leave_requests"),
        'icon': Icons.beach_access,
        'color': Colors.orange,
        'screen': const leave_screen.LeaveManagementScreen(),
      },
      {
        'title': localization.translate("salary_advances"),
        'icon': Icons.attach_money,
        'color': Colors.green,
        'screen': const salary_screen.SalaryAdvanceManagementScreen(),
      },
      {
        'title': localization.translate("attendance"),
        'icon': Icons.access_time,
        'color': Colors.blueGrey,
        'screen': const attendance_screen.AttendanceOverviewScreen(),
      },
      {
        'title': localization.translate("geo_fence"),
        'icon': Icons.my_location,
        'color': Colors.lightBlue,
        'screen': const geo_screen.GeoFenceManagementScreen(),
      },
      {
        'title': localization.translate("announcements"),
        'icon': Icons.announcement,
        'color': Colors.amber,
        'screen': const announcement_screen.AnnouncementManagementScreen(),
      },
      {
        'title': localization.translate("reports"),
        'icon': Icons.insert_drive_file,
        'color': Colors.brown,
        'screen': const report_screen.ReportGenerationScreen(),
      },
      {
        'title': localization.translate("manage_products"),
        'icon': Icons.shopping_cart,
        'color': Colors.pinkAccent,
        'screen': const product_manage_screen.ProductManagementScreen(),
      },
      {
        'title': localization.translate("products"),
        'icon': Icons.store,
        'color': Colors.cyan,
        'screen': const product_list_screen.ProductListScreen(),
      },
      {
        'title': localization.translate("users"),
        'icon': Icons.people,
        'color': Colors.deepPurple,
        'screen': const user_screen.UserManagementScreen(),
      },
      {
        'title': localization.translate("manage_branch"),
        'icon': Icons.business,
        'color': Colors.deepOrange,
        'screen': const org_screen.OrganisationManagementScreen(),
      },
      {
        'title': localization.translate("customers_list"),
        'icon': Icons.list_alt,
        'color': Colors.blueGrey,
        'screen': const customer_screen.CustomerListScreen(),
      },
    ];
    return Scaffold(
      // We use a Stack here so we can overlay a loading indicator
      body: Stack(
        children: [
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfileSection(),
                const AnnouncementCard(role: "admin"),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Page 1: Dashboard Tiles with pull-to-refresh
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: GridView.builder(
                            itemCount: dashboardItems.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final item = dashboardItems[index];
                              return DashboardTile(
                                title: item['title'],
                                icon: item['icon'],
                                color: item['color'],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => item['screen'],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      // Page 2: Overview Card with pull-to-refresh
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: const OverviewCard(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Show a loading indicator overlay if we're loading
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
