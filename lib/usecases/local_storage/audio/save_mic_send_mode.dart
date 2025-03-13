import '../../../data/dynamic_factories.dart';
import '../../../data/enums/mic_send_mode.dart';

Future<void> saveMicSendMode(MicSendMode mode) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();
  await rep.saveMicSendMode(mode);
}
