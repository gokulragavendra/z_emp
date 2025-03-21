import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/admin_dashboard_content.dart';
import '../manager/manager_dashboard_content.dart';
import '../sales_staff/sales_dashboard_content.dart';
import '../measurement_staff/measurement_dashboard_content.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const LoginScreen();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Error retrieving user data.')),
          );
        } else {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final userRole = userData['role'] as String?;
          if (userRole == null || userRole.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          switch (userRole) {
            case 'Admin':
              return const AdminDashboardContent();
            case 'Manager':
              return const ManagerDashboardContent();
            case 'Sales Staff':
              return const SalesDashboardContent();
            case 'Measurement Staff':
              return const MeasurementDashboardContent();
            default:
              return const Scaffold(
                body: Center(child: Text('Invalid role.')),
              );
          }
        }
      },
    );
  }
}
