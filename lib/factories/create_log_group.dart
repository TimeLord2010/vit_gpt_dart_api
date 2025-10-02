import 'package:logger/logger.dart';

import '../data/dynamic_factories.dart';

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
  var fn = DynamicFactories.logger;
  if (fn != null) {
    return fn(tag);
  }
  return Logger(
    printer: LogGroup(
      tag: tag,
    ),
  );
}
