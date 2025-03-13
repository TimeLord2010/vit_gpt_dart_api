import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/data/configuration.dart';

class LogGroup extends LogPrinter {
  final List<String> tags;
  final String separator;

  LogGroup({
    required this.tags,
    this.separator = ':',
  });

  @override
  List<String> log(LogEvent event) {
    var prefix = ['VitGptDart', ...tags].join(separator);
    var msg = event.message;

    return [
      '($prefix) [${event.level.name.toUpperCase()}] $msg',
    ];
  }
}

Logger createLogger(List<String> tags) {
  return Logger(
    //filter: AlwaysLogFilter(),
    level: VitGptDartConfiguration.logLevel,
    printer: LogGroup(
      tags: tags,
    ),
  );
}
