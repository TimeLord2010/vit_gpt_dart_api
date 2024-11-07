import '../../../data/dynamic_factories.dart';
import '../../../data/enums/mic_send_mode.dart';

Future<void> saveMicSendMode(MicSendMode mode) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveMicSendMode(mode);
}
