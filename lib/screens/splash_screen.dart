import 'package:aws_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        Navigator.pushReplacementNamed(context, '/home_page');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            // const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
