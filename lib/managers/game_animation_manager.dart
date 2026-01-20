import 'package:flutter/material.dart';

class GameAnimationManager {
  bool _animate = false;
  double _scale1 = 0;
  double _scale2 = 0;
  double _scale3 = 0;
  Offset _hintOffset = const Offset(-1.5, 0);
  Offset _restartOffset = const Offset(1.5, 0);
  int _animationKey = 0;

  // Getters
  bool get animate => _animate;
  double get scale1 => _scale1;
  double get scale2 => _scale2;
  double get scale3 => _scale3;
  Offset get hintOffset => _hintOffset;
  Offset get restartOffset => _restartOffset;
  int get animationKey => _animationKey;

  void reset() {
    _animate = false;
    _scale1 = 0;
    _scale2 = 0;
    _scale3 = 0;
    _hintOffset = const Offset(-1.5, 0);
    _restartOffset = const Offset(1.5, 0);
  }

  void setAnimate(bool value) => _animate = value;
  void setScale1(double value) => _scale1 = value;
  void setScale2(double value) => _scale2 = value;
  void setScale3(double value) => _scale3 = value;
  void setHintOffset(Offset value) => _hintOffset = value;
  void setRestartOffset(Offset value) => _restartOffset = value;
  void incrementKey() => _animationKey++;

  Future<void> startAnimations(
    Function(VoidCallback) setState,
    bool mounted,
  ) async {
    reset();
    setState(() {});

    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) {
      _animate = true;
      _hintOffset = Offset.zero;
      _restartOffset = Offset.zero;
      setState(() {});
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      _scale1 = 1;
      setState(() {});
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _scale2 = 1;
      setState(() {});
    }

    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      _scale3 = 1;
      setState(() {});
    }
  }

  void replayAnimations(Function(VoidCallback) setState, bool mounted) {
    incrementKey();
    setState(() {});
    startAnimations(setState, mounted);
  }
}
