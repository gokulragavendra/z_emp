// lib/main.dart

// ignore_for_file: unused_import, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure Google Fonts is imported
import 'package:z_emp/providers/announcement_provider.dart';
import 'package:z_emp/providers/notifications_provider.dart';
import 'package:z_emp/providers/todo_task_provider.dart';

import 'package:z_emp/services/customer_service.dart';
import 'package:z_emp/services/leave_management_service.dart';
import 'package:z_emp/services/messaging_service.dart';
import 'package:z_emp/services/product_service.dart';
import 'package:z_emp/services/role_service.dart';
import 'package:z_emp/services/attendance_service.dart';
import 'package:z_emp/services/enquiry_service.dart';
import 'package:z_emp/services/firestore_service.dart';
import 'package:z_emp/services/leave_request_service.dart';
import 'package:z_emp/services/log_service.dart';
import 'package:z_emp/services/measurement_service.dart';
import 'package:z_emp/services/notification_service.dart';
import 'package:z_emp/services/performance_service.dart';
import 'package:z_emp/services/salary_advance_service.dart';
import 'package:z_emp/services/sales_service.dart';
import 'package:z_emp/services/task_service.dart';
import 'package:z_emp/services/todo_task_service.dart';
import 'package:z_emp/services/user_service.dart';
import 'package:z_emp/services/follow_up_service.dart';
import 'package:z_emp/services/organisation_service.dart';
import 'package:z_emp/utils/theme.dart';

import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/user_provider.dart';

import 'auth/auth_service.dart';

import 'l10n/app_localizations.dart';

import 'screens/auth/login_screen.dart';
import 'widgets/main_scaffold.dart';

import 'firebase_options.dart';

// FIX: background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If not already initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FIX: Setup background handling for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Run the app with MultiProvider
  runApp(
    MultiProvider(
      providers: [
        // Authentication Service
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        // Theme and Locale Providers
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<TodoTaskProvider>(
          create: (_) => TodoTaskProvider(),
        ),

        // Other Services
        Provider<TodoTaskService>(create: (_) => TodoTaskService()),
        Provider<ProductService>(
          create: (_) => ProductService(),
        ),
        Provider<CustomerService>(
          create: (_) => CustomerService(),
        ),
        Provider<RoleService>(
          create: (_) => RoleService(),
        ),
        Provider<AttendanceService>(
          create: (_) => AttendanceService(),
        ),
        Provider<EnquiryService>(
          create: (_) => EnquiryService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        Provider<LogService>(
          create: (_) => LogService(),
        ),
        Provider<MeasurementService>(
          create: (_) => MeasurementService(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        Provider<PerformanceService>(
          create: (_) => PerformanceService(),
        ),
        Provider<SalaryAdvanceService>(
          create: (_) => SalaryAdvanceService(),
        ),
        Provider<LeaveManagementService>(
          create: (_) => LeaveManagementService(),
        ),
        Provider<SalesService>(
          create: (_) => SalesService(),
        ),
        Provider<TaskService>(
          create: (_) => TaskService(),
        ),
        Provider<UserService>(
          create: (_) => UserService(),
        ),
        Provider<FollowUpService>(
          create: (_) => FollowUpService(),
        ),
        Provider<OrganisationService>(
          create: (_) => OrganisationService(),
        ),
        Provider<LeaveRequestService>(
          create: (_) => LeaveRequestService(),
        ),
        Provider<MessagingService>(
          create: (_) => MessagingService(),
        ),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<TodoTaskProvider>(
          create: (_) => TodoTaskProvider(),
        ),
        // Other Services…
        Provider<TodoTaskService>(
          create: (_) => TodoTaskService(),
        ),
        Provider<ProductService>(
          create: (_) => ProductService(),
        ),
        Provider<CustomerService>(
          create: (_) => CustomerService(),
        ),
        Provider<RoleService>(
          create: (_) => RoleService(),
        ),
        Provider<AttendanceService>(
          create: (_) => AttendanceService(),
        ),
        Provider<EnquiryService>(
          create: (_) => EnquiryService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        Provider<LogService>(
          create: (_) => LogService(),
        ),
        Provider<MeasurementService>(
          create: (_) => MeasurementService(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        Provider<PerformanceService>(
          create: (_) => PerformanceService(),
        ),
        Provider<SalaryAdvanceService>(
          create: (_) => SalaryAdvanceService(),
        ),
        Provider<LeaveManagementService>(
          create: (_) => LeaveManagementService(),
        ),
        Provider<SalesService>(
          create: (_) => SalesService(),
        ),
        Provider<TaskService>(
          create: (_) => TaskService(),
        ),
        Provider<UserService>(
          create: (_) => UserService(),
        ),
        Provider<FollowUpService>(
          create: (_) => FollowUpService(),
        ),
        Provider<OrganisationService>(
          create: (_) => OrganisationService(),
        ),
        Provider<LeaveRequestService>(
          create: (_) => LeaveRequestService(),
        ),
        Provider<MessagingService>(
          create: (_) => MessagingService(),
        ),
        // --- New Providers ---
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(),
        ),
        // Add other providers here as needed
      ],
      child: const MyApp(),
    ),
  );
}

/// Sets up Firebase Cloud Messaging (FCM)
Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request notification permissions (iOS)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Delay a little to ensure the widget tree is built
    Future.microtask(() {
      Provider.of<NotificationService>(context, listen: false)
          .initNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access Providers
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    // FIX: Request notification permissions + get token
    //  do this once, perhaps in an init method or in a widget

    return MaterialApp(
      title: 'Employee Management App',
      debugShowCheckedModeBanner: false,

      // Theme Configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // Localization Configuration
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ta'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate,
      ],

      // Initial Route
      home: const AuthWrapper(),
    );
  }

  Future<void> _setupFCM(BuildContext context) async {
    // Request permission for iOS (and Android 13+)
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received a message in the foreground: ${message.messageId}');
      if (message.notification != null) {
        print('Message has a notification: ${message.notification!.title}');
      }
      // Optionally display local notification or update UI
    });

    // OnMessageOpenedApp
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened from background: ${message.messageId}');
      // Navigate or do other handling
    });

    // Print token
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM Registration Token: $token');
    if (token != null) {
      // Optionally store token in Firestore or your server
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    }
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (authSnapshot.hasData) {
          // If user is logged in, ensure user data is loaded
          final currentUser = authService.currentUser;
          if (currentUser != null && userProvider.user == null) {
            userProvider.loadCurrentUser(currentUser.uid);
          }
          return const MainScaffold();
        } else {
          // Not logged in
          return const LoginScreen();
        }
      },
    );
  }
}
