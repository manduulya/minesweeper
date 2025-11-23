import 'package:flutter/material.dart';
import 'sound_manager.dart';

class ClickButton extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onPressed;
  final ButtonStyle? style;

  const ClickButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
  });

  @override
  State<ClickButton> createState() => _ClickButtonState();
}

class _ClickButtonState extends State<ClickButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),

          // 🔥 3D SHADOW CHANGE (no scaling)
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2), // lower + softer
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 14,
                    offset: const Offset(0, 6), // deeper + stronger
                  ),
                ],
        ),

        // 🟦 COLOR CHANGE (to simulate depth)
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isPressed
                  ? [
                      const Color(0xFF0A162F), // darker top
                      const Color(0xFF0B1E3D), // original
                    ]
                  : [
                      const Color(0xFF122A55), // lighter glossy top
                      const Color(0xFF0B1E3D), // original
                    ],
            ),

            // border brightens slightly on press
            border: Border.all(
              color: _isPressed
                  ? const Color(0xFFFFA200).withOpacity(0.7)
                  : const Color(0xFFFFA200),
              width: 3,
            ),
          ),

          child: ElevatedButton(
            style: widget.style,
            onPressed: widget.onPressed == null
                ? null
                : () async {
                    SoundManager.playClick();
                    await widget.onPressed!();
                  },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
