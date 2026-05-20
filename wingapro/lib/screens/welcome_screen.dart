// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width to adjust text constraints
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Animated Logo
              ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/images/wingapro.png',
                  width: 250,
                  height: 250,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.wifi_tethering,
                      size: 120,
                      color: Colors.white,
                    );
                  },
                ),
              ),

                            // Company name
              const Text(
                'WINGA PRO',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 12,
                      color: Colors.black26,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 0),
              // Subtitle - Fixed to avoid overflow and fit well
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08), // 8% of screen width on each side
                child: const Text(
                  'Smart Internet Business Management System',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,         // ensures text wraps onto multiple lines
                  overflow: TextOverflow.visible, // prevents clipping
                ),
              ),
              const Spacer(flex: 3),
              // Clean "Get Started" – no button container, just text
              GestureDetector(
                onTap: _navigateToLogin,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decorationColor: Colors.white,
                      decorationThickness: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}