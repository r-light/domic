import 'package:logger/logger.dart';

/// logger 类型
enum LoggerType {
  trace,
  debug,
  info,
  warning,
  error,
}

class LoggerUtil {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      colors: true,
      printTime: true,
    ),
  );

  /// 写log
  static void log(
    dynamic message, {
    LoggerType type = LoggerType.debug,
  }) {
    switch (type) {
      case LoggerType.trace:
        _logger.t(message);
        break;
      case LoggerType.debug:
        _logger.d(message);
        break;
      case LoggerType.info:
        _logger.i(message);
        break;
      case LoggerType.warning:
        _logger.w(message);
        break;
      case LoggerType.error:
        _logger.e(message);
        break;
      default:
        _logger.d(message);
    }
  }
}
