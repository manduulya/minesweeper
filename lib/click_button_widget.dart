import 'package:flutter/material.dart';
import 'sound_manager.dart';

class ClickButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final ButtonStyle? style;

  const ClickButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: () {
        SoundManager.playClick(); // play sound
        onPressed(); // execute action
      },
      child: child,
    );
  }
}
