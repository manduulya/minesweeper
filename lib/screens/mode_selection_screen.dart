import 'package:flutter/material.dart';
import '../board.dart';
import '../sound_manager.dart';
import 'tutorial_screen.dart';
import 'world_map_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset('assets/background1.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.45)),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      SoundManager.playClick();
                      Navigator.of(context).pop();
                    },
                  ),
                ),

                const Spacer(),

                // Title
                const Text(
                  'SELECT MODE',
                  style: TextStyle(
                    color: Color(0xFFFFDD00),
                    fontFamily: 'Acsioma',
                    fontSize: 28,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Reveal the World button
                _ModeButton(
                  title: 'REVEAL THE WORLD',
                  subtitle: 'Uncover countries on a world map',
                  icon: Icons.public,
                  onTap: () {
                    SoundManager.playClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorldMapScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Career Mode button
                _ModeButton(
                  title: 'CAREER MODE',
                  subtitle: '200 handcrafted levels',
                  icon: Icons.military_tech,
                  onTap: () async {
                    SoundManager.playClick();
                    final showTutorial = await TutorialScreen.shouldShow();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => showTutorial
                            ? const TutorialScreen()
                            : const GameBoard(),
                      ),
                    );
                  },
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1E3D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFA200),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFA200).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF00D4FF), size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFFFDD00),
                          fontFamily: 'Acsioma',
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFFFDD00),
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
