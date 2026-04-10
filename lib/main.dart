import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Theme and Utils
import 'theme/app_theme.dart';
import 'utils/user_role.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboards/customer_home.dart';
import 'screens/dashboards/provider_dashboard.dart';
import 'screens/auth/intro_screen.dart';
import 'screens/misc/how_it_works_screen.dart';
import 'screens/auth/provider_register_screen.dart';
import 'screens/dashboards/admin_dashboard.dart';
import 'screens/provider/add_service_screen.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const GoServeApp());
}

class GoServeApp extends StatelessWidget {
  const GoServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoServe',

      // ROLE-BASED THEME SWITCH
      theme:
          UserRole.currentRole == 'Provider'
              ? AppTheme.providerTheme
              : AppTheme.customerTheme,

      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const IntroScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/provider-register': (context) => const ProviderRegisterScreen(),
        '/customer': (context) => const CustomerHome(),
        '/provider': (context) => const ProviderDashboard(),
        '/add-service': (context) => const AddServiceScreen(),
        '/how_it_works': (context) => const HowItWorksScreen(),
        '/admin':
            (context) => const AdminDashboardScreen(), // 🔹 ADDED THIS LINE
      },
    );
  }
}
