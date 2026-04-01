// lib/utils/error_handler.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ErrorHandler {
  void showError(BuildContext context, String message) {
    _showTopBanner(context, message, Colors.red, const Duration(seconds: 3));
  }

  void showSuccess(BuildContext context, String message) {
    _showTopBanner(context, message, Colors.green, const Duration(seconds: 2));
  }

  void _showTopBanner(
    BuildContext context,
    String message,
    Color color,
    Duration duration,
  ) {
    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopBanner(
        message: message,
        color: color,
        topPadding: topPadding,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void handleError(BuildContext context, dynamic error) {
    String message = 'An unexpected error occurred';

    if (error is http.ClientException) {
      message =
          'Network connection failed. Please check your internet connection.';
    } else if (error is http.Response) {
      // Handle HTTP response errors
      try {
        final data = jsonDecode(error.body);
        message = data['error'] ?? 'Server error occurred';
      } catch (e) {
        message = 'Server returned status ${error.statusCode}';
      }
    } else if (error is FormatException) {
      message = 'Invalid response format from server';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Request timed out. Please try again.';
    }

    showError(context, message);
  }

  // Handle specific API errors
  String getErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error'] ?? 'Unknown error occurred';
    } catch (e) {
      switch (response.statusCode) {
        case 400:
          return 'Bad request. Please check your input.';
        case 401:
          return 'Authentication failed. Please log in again.';
        case 403:
          return 'Access denied.';
        case 404:
          return 'Resource not found.';
        case 409:
          return 'Conflict. Data already exists.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'HTTP Error ${response.statusCode}';
      }
    }
  }
}

class _TopBanner extends StatefulWidget {
  final String message;
  final Color color;
  final double topPadding;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopBanner({
    required this.message,
    required this.color,
    required this.topPadding,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
