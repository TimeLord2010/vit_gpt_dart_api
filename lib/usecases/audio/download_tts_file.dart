import 'dart:io';

import 'package:vit_gpt_dart_api/data/configuration.dart';

import '../../data/enums/audio_format.dart';
import '../../repositories/tts_repository.dart';

Future<File> downloadTTSfile({
  required String voice,
  required String input,
  Directory? folder,
}) async {
  folder ??= VitGptConfiguration.internalFilesDirectory;

  var rep = TTSRepository();
  var format = AudioFormat.opus;
  var stream = rep.getAudio(
    voice: voice,
    input: input,
    format: format,
  );
  var now = DateTime.now();
  var dateStr = '[${now.year}${now.month}${now.day}]';

  var hour = now.hour.toString().padLeft(2, '0');
  var minute = now.minute.toString().padLeft(2, '0');
  var second = now.second.toString().padLeft(2, '0');
  var milli = now.millisecond.toString().padLeft(3, '0');
  var timeStr = '$hour$minute$second-$milli';

  var name = 'audio$dateStr$timeStr.${format.name}';
  var file = File('${folder.path}/$name');

  var write = file.openWrite();
  await write.addStream(stream);
  await write.close();

  return file;
}
