import 'dart:io';

import '../../factories/create_transcriber_repository.dart';

@Deprecated('Use "createListenerRepository" to create a transcribe class')
Future<String> transcribe(File file) async {
  var rep = createTranscriberRepository();
  var text = await rep.transcribeFromFile(file);
  return text;
}
