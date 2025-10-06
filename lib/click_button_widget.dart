import 'package:flutter/material.dart';
import 'sound_manager.dart';

class ClickButton extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onPressed; // allow async
  final ButtonStyle? style;

  const ClickButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: onPressed == null
          ? null
          : () async {
              SoundManager.playClick();
              await onPressed!(); // properly await async action
            },
      child: child,
    );
  }
}
