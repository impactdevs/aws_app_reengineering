import 'package:aws_app/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isPasswordVisible = false;
  int _retryCount = 0;
  static const int maxRetries = 3;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    // if (value.length < 6) {
    //   return 'Password must be at least 6 characters';
    // }
    return null;
  }

  Future<void> _handleLogin() async {
    _clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // try {
    await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    // Ensure user is loaded from storage/provider
    //await authProvider.loadUser();

    // Reset retry count on successful login
    _retryCount = 0;

    // Check if user is valid after login
    if (authProvider.user?['user_id'] == null) {
      setState(() => _errorMessage = 'Login failed: Invalid user data');
      return;
    }

    // Fetch region data for user
    try {
      await authProvider.loadUserRegionData(
        authProvider.user!['user_id'],
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Login succeeded, but failed to load user region data.';
      });
      return;
    }

    // Check if widget is still mounted before showing SnackBar or navigating
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login successful!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const HomePage()));

    // } catch (e) {
    //   if (!mounted) return;

    //   _retryCount++;
    //   final userFriendlyError = ErrorHandler.getLoginErrorMessage(e);
    //   setState(() {
    //     _errorMessage = userFriendlyError;
    //   });

    //   // Show different messages based on retry count
    //   String snackBarMessage = userFriendlyError;
    //   if (_retryCount >= maxRetries) {
    //     snackBarMessage =
    //         '$userFriendlyError\n\nYou can try again or contact support if the problem persists.';
    //   }

    //   // Also show as snackbar for immediate feedback
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(snackBarMessage),
    //       backgroundColor: Colors.red,
    //       duration: const Duration(seconds: 4),
    //       action: SnackBarAction(
    //         label: 'Dismiss',
    //         textColor: Colors.white,
    //         onPressed: () {
    //           ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //         },
    //       ),
    //     ),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Curved background images
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.15,
            child: ClipPath(
              clipper: TopLeftCurveClipper(),
              child: Opacity(
                opacity: 0.22,
                child: Image.asset(
                  'assets/images/img_1.jpg',
                  width: size.width * 0.7,
                  height: size.height * 0.38,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.10,
            right: -size.width * 0.18,
            child: ClipPath(
              clipper: BottomRightCurveClipper(),
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/img_2.jpg',
                  width: size.width * 0.65,
                  height: size.height * 0.32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.32,
            left: -size.width * 0.12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(80),
              child: Opacity(
                opacity: 0.13,
                child: Image.asset(
                  'assets/images/img_3.jpg',
                  width: size.width * 0.5,
                  height: size.height * 0.22,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Main login content
          Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                color: Colors.white.withOpacity(0.97),
                margin: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                    vertical: size.height * 0.05,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 48,
                            backgroundImage:
                                AssetImage('assets/images/logo.png'),
                            backgroundColor: Colors.white,
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),
                        Text(
                          'Sign in',
                          style: GoogleFonts.lato(
                            fontSize: size.height * 0.032,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => _clearError(),
                          validator: _validateEmail,
                          enabled: !authProvider.isLoading,
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'Your e-mail',
                            prefixIcon: const Icon(Icons.email),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.022),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          onChanged: (_) => _clearError(),
                          validator: _validatePassword,
                          enabled: !authProvider.isLoading,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Your password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (_retryCount > 0)
                                        Text(
                                          'Attempt $_retryCount of $maxRetries',
                                          style: TextStyle(
                                            color: Colors.red.shade600,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      color: Colors.red.shade600, size: 18),
                                  onPressed: _clearError,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        authProvider.isLoading
                            ? Column(
                                children: [
                                  const CircularProgressIndicator(),
                                  SizedBox(height: size.height * 0.02),
                                  Text('Signing in...',
                                      style: GoogleFonts.lato(fontSize: 15)),
                                ],
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    'SIGN IN',
                                    style: GoogleFonts.lato(
                                      fontSize: 17,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom clippers for curved images
class TopLeftCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.5, size.height, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomRightCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.3);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
