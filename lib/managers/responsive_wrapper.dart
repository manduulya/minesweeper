// lib/widgets/responsive_wrapper.dart
import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding:
            padding ?? EdgeInsets.symmetric(horizontal: _getPadding(context)),
        child: child,
      ),
    );
  }

  double _getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1024) return 48;
    if (width > 600) return 32;
    return 24;
  }
}
