// lib/utils/error_handler.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ErrorHandler {
  void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
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
