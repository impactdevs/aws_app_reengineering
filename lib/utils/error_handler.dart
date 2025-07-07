import 'package:dio/dio.dart';

class ErrorHandler {
  static String getLoginErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection and try again.';
        case DioExceptionType.connectionError:
          return 'Unable to connect to server. Please check your internet connection.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final responseData = error.response?.data;
          String errorMessage = 'Login failed';

          if (responseData is Map<String, dynamic>) {
            errorMessage = responseData['message'] ??
                responseData['error'] ??
                errorMessage;
          }

          switch (statusCode) {
            case 401:
              return 'Invalid credentials. Please check your email and password.';
            case 403:
              return 'Access denied. Your account may be disabled or you don\'t have permission to access this application.';
            case 404:
              return 'User account not found. Please check your email address.';
            case 500:
              return 'Server error. Please try again later or contact support if the problem persists.';
            default:
              return 'Login failed: $errorMessage';
          }
        case DioExceptionType.cancel:
          return 'Login request was cancelled.';
        default:
          return 'Network error. Please check your internet connection and try again.';
      }
    } else if (error is Exception) {
      final errorString = error.toString();
      if (errorString.contains('SocketException')) {
        return 'Unable to connect to server. Please check your internet connection.';
      } else if (errorString.contains('timeout')) {
        return 'Connection timeout. Please check your internet connection and try again.';
      } else if (errorString.contains('401') ||
          errorString.contains('Unauthorized')) {
        return 'Invalid credentials. Please check your email and password.';
      } else if (errorString.contains('403') ||
          errorString.contains('Forbidden')) {
        return 'Access denied. Your account may be disabled or you don\'t have permission to access this application.';
      } else if (errorString.contains('404') ||
          errorString.contains('Not Found')) {
        return 'User account not found. Please check your email address.';
      } else if (errorString.contains('500') ||
          errorString.contains('Internal Server Error')) {
        return 'Server error. Please try again later or contact support if the problem persists.';
      } else {
        return 'Login failed. Please try again or contact support if the problem persists.';
      }
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static String getNetworkErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection and try again.';
        case DioExceptionType.connectionError:
          return 'Unable to connect to server. Please check your internet connection.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          switch (statusCode) {
            case 500:
              return 'Server error. Please try again later.';
            case 404:
              return 'Resource not found.';
            default:
              return 'Request failed. Please try again.';
          }
        default:
          return 'Network error. Please check your internet connection and try again.';
      }
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static String getFormSubmissionErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Your form data has been saved locally and will be submitted when connection is restored.';
        case DioExceptionType.connectionError:
          return 'Unable to connect to server. Your form data has been saved locally and will be submitted when connection is restored.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          switch (statusCode) {
            case 500:
              return 'Server error. Your form data has been saved locally and will be submitted when the server is available.';
            case 401:
              return 'Session expired. Please log in again.';
            default:
              return 'Submission failed. Your form data has been saved locally and will be submitted when possible.';
          }
        default:
          return 'Network error. Your form data has been saved locally and will be submitted when connection is restored.';
      }
    } else {
      return 'Submission failed. Your form data has been saved locally and will be submitted when possible.';
    }
  }

  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
    }
    return error.toString().contains('SocketException') ||
        error.toString().contains('timeout') ||
        error.toString().contains('Network');
  }

  static bool isServerError(dynamic error) {
    if (error is DioException && error.type == DioExceptionType.badResponse) {
      final statusCode = error.response?.statusCode;
      return statusCode != null && statusCode >= 500;
    }
    return error.toString().contains('500') ||
        error.toString().contains('Internal Server Error');
  }

  static bool isAuthenticationError(dynamic error) {
    if (error is DioException && error.type == DioExceptionType.badResponse) {
      final statusCode = error.response?.statusCode;
      return statusCode == 401 || statusCode == 403;
    }
    return error.toString().contains('401') ||
        error.toString().contains('403') ||
        error.toString().contains('Unauthorized') ||
        error.toString().contains('Forbidden');
  }
}
