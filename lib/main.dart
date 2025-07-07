// main.dart
import 'package:aws_app/services/commit_service.dart';

import 'services/offline_service.dart';
import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/activity_page.dart';
import 'screens/details_page.dart';
import 'screens/dynamic_form_page.dart';
import 'screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'services/draft_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload Google Fonts to handle errors gracefully
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.poppins(),
    ]);
  } catch (e) {
    debugPrint('Google Fonts failed to load: $e');
    // Continue with app initialization even if fonts fail
  }

  final authProvider = AuthProvider();
  final draftService = DraftService();
  final commitService = CommitService();
  final offlineStorage = OfflineStorageService();
  await Future.wait([
    authProvider.loadUser(),
    draftService.init(),
    commitService.init(),
    offlineStorage.init(),
  ]);
  
  // Set the initialized CommitService in AuthProvider
  authProvider.setCommitService(commitService);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider.value(value: draftService),
        Provider.value(value: commitService),
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
      theme: ThemeData(
        // Use system fonts as fallback
        fontFamily: 'Roboto',
        textTheme: TextTheme(
          headlineLarge: TextStyle(fontFamily: 'Roboto'),
          headlineMedium: TextStyle(fontFamily: 'Roboto'),
          headlineSmall: TextStyle(fontFamily: 'Roboto'),
          titleLarge: TextStyle(fontFamily: 'Roboto'),
          titleMedium: TextStyle(fontFamily: 'Roboto'),
          titleSmall: TextStyle(fontFamily: 'Roboto'),
          bodyLarge: TextStyle(fontFamily: 'Roboto'),
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
          bodySmall: TextStyle(fontFamily: 'Roboto'),
          labelLarge: TextStyle(fontFamily: 'Roboto'),
          labelMedium: TextStyle(fontFamily: 'Roboto'),
          labelSmall: TextStyle(fontFamily: 'Roboto'),
        ),
      ),
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
