import 'package:flutter/material.dart';
import 'screens/animated_splash_screen.dart';

void main() => runApp(const MinesweeperApp());

class MinesweeperApp extends StatelessWidget {
  const MinesweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mine Master',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1E3D), // Navy Blue
        colorScheme: ColorScheme.dark(
          primary: Color.fromARGB(255, 255, 136, 0),
          secondary: const Color(0xFFC0C0C0), // Silver
          surface: const Color(
            0xFF102A43,
          ), // Slightly lighter navy for cards/tiles
        ),
        textTheme: ThemeData.dark().textTheme
            .copyWith(
              bodyLarge: const TextStyle(
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              bodyMedium: const TextStyle(
                color: Color(0xFFC0C0C0),
                decoration: TextDecoration.none,
              ),
              titleLarge: const TextStyle(
                color: Color.fromARGB(255, 255, 136, 0),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            )
            .apply(
              decoration:
                  TextDecoration.none, // ← Ensures no underline anywhere
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 255, 136, 0),
            foregroundColor: const Color(
              0xFF0B1E3D,
            ), // Navy text on yellow button
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home:
          const AnimatedSplashScreen(), // splash can navigate to LandingPage instead of GameBoard
      // OR directly start with landing:
      // home: const LandingPage(),
    );
  }
}
