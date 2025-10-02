import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/data/configuration.dart';

class LogGroup extends LogPrinter {
  final String tag;
  final String separator;

  LogGroup({
    required this.tag,
    this.separator = ':',
  });

  @override
  List<String> log(LogEvent event) {
    var prefix = ['VitGptDart', tag].join(separator);
    var msg = event.message;

    var dt = DateTime.now();
    var timeStr = dt.toIso8601String().split('T')[1];

    return [
      '($prefix) [${event.level.name.toUpperCase()}] $timeStr: $msg',
    ];
  }
}

Logger createGptDartLogger(String tag) {
  return Logger(
    level: VitGptDartConfiguration.logLevel,
    printer: LogGroup(
      tag: tag,
    ),
  );
}
