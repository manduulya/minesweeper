import 'package:flutter/material.dart';

void showLevelOverlay(BuildContext context, int level) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  final opacityNotifier = ValueNotifier<double>(0.0);

  entry = OverlayEntry(
    builder: (context) {
      return Center(
        child: ValueListenableBuilder<double>(
          valueListenable: opacityNotifier,
          builder: (context, opacity, child) {
            return AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 800),
              child: Text(
                'Level $level',
                style: const TextStyle(
                  fontFamily: 'Topaz',
                  fontSize: 48,
                  fontWeight: FontWeight.normal,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 3.0,
                      color: Colors.black54,
                    ),
                  ],
                  color: Color(0xFFffdd00),
                  decoration: TextDecoration.none,
                ),
              ),
            );
          },
        ),
      );
    },
  );

  overlay.insert(entry);

  // 🔑 Schedule fade-in on the next frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    opacityNotifier.value = 1.0;
  });

  // Fade out after ~1.6s
  Future.delayed(const Duration(milliseconds: 1600), () {
    opacityNotifier.value = 0.0;
  });

  // Remove after fade-out completes
  Future.delayed(const Duration(milliseconds: 2400), () {
    entry.remove();
    opacityNotifier.dispose();
  });
}
