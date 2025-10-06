import 'dart:async';
import 'package:flutter/material.dart';
// import 'landing_page.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback? onSplashComplete;

  const AnimatedSplashScreen({super.key, this.onSplashComplete});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    Timer(const Duration(seconds: 3), () {
      if (widget.onSplashComplete != null) {
        widget.onSplashComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🧭 Entered AnimatedSplashScreen');
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 20, 25, 51),
      body: Center(
        child: RotationTransition(
          turns: _controller,
          child: Image.asset('assets/appicon.png', width: 100, height: 100),
        ),
      ),
    );
  }
}
