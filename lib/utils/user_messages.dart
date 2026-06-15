import 'package:flutter/foundation.dart';

/// Maps internal errors to user-safe messages.
class UserMessages {
  UserMessages._();

  static String forOperation(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('$operation failed: $error');
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input for $operation.';
    }
    if (error is UnsupportedError) {
      return error.message ?? 'This operation is not supported on this platform.';
    }

    return '$operation failed. Check your network settings and try again.';
  }
}
