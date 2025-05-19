// main.dart
import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/activity_page.dart';
import 'screens/details_page.dart';
import 'screens/dynamic_form_page.dart';
import 'screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'services/draft_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  final draftService = DraftService();
  await Future.wait([
    authProvider.loadUser(),
    draftService.init(),
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider.value(value: draftService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/home_page': (context) => const HomePage(),
        '/activity_page': (context) => ActivityPage(),
        '/details_page': (context) => const DetailsPage(),
        '/form_page': (context) => const DynamicFormPage(),
        '/login': (context) => const LoginPage(),
      },
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          if (auth.user == null) {
            return const LoginPage();
          } else {
            return const HomePage();
          }
        },
      ),
    );
  }
}
