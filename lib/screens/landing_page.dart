import 'package:flutter/material.dart';
import '../board.dart'; // or wherever GameBoard lives

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4), // new background color
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game title
                Image.asset(
                  'assets/WelcomeTitle.png',
                  width: 300, // adjust as needed
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/landingPageLogo.png',
                  width: 200, // adjust as needed
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),

                // Optional: short instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Clear all safe tiles without hitting a mine. Build streaks to earn bonus points.',
                    style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 15),

                // Play button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const GameBoard()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        EdgeInsets.zero, // Remove default padding for image fit
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors
                        .transparent, // Transparent to show only the image
                    shadowColor:
                        Colors.transparent, // Optional: remove button shadow
                  ),
                  child: Image.asset(
                    'assets/playButton.png', // Your PNG asset
                    width: 280, // Adjust as needed
                    height: 56, // Adjust as needed
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
