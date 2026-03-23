// User/Account Exceptions
class UserNotFoundException implements Exception {
  final String message;
  UserNotFoundException([this.message = 'User not found']);

  @override
  String toString() => message;
}

class AccountNotFoundException implements Exception {
  final String message;
  AccountNotFoundException([this.message = 'Account not found']);

  @override
  String toString() => message;
}

// Authentication Exceptions
class WrongPasswordException implements Exception {
  final String message;
  WrongPasswordException([this.message = 'Wrong password']);

  @override
  String toString() => message;
}

class UnknownLoginException implements Exception {
  final String message;
  UnknownLoginException([this.message = 'Unknown login error']);

  @override
  String toString() => message;
}

// Network/Server Exceptions
class ServerTimeoutException implements Exception {
  final String message;
  ServerTimeoutException([this.message = 'Server timeout']);

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network error']);

  @override
  String toString() => message;
}

// Password Reset Exceptions
class PasswordResetException implements Exception {
  final String message;
  PasswordResetException([this.message = 'Password reset failed']);

  @override
  String toString() => message;
}
