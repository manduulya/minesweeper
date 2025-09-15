import 'package:flutter/material.dart';

class AnimatedStars extends StatefulWidget {
  const AnimatedStars({super.key});

  @override
  State<AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<AnimatedStars>
    with TickerProviderStateMixin {
  final List<bool> _starVisible = [false, false, false, false, false];
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();

    // Create animation controllers for each star
    _controllers = List.generate(
      5,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    // Create scale animations for each star
    _scaleAnimations = _controllers
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.elasticOut),
            // Different bounce effect
            // curve: Curves.bounceOut
            // curve: Curves.backOut
          ),
        )
        .toList();

    // Start the sequential animation
    _startSequentialAnimation();
  }

  void _startSequentialAnimation() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(
        Duration(milliseconds: i * 150),
      ); // 150ms delay between stars
      if (mounted) {
        setState(() {
          _starVisible[i] = true;
        });
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _scaleAnimations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _starVisible[index]
                    ? _scaleAnimations[index].value
                    : 0.0,
                child: Image.asset(
                  'assets/star.png',
                  width: 30,
                  height: 30,
                  // Optional: add color filter if you want to tint the image
                  // color: Color(0xFFFF8C00), // This will tint the image orange
                  colorBlendMode: BlendMode.modulate,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
