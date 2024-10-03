import 'package:chatgpt_chat/data/enums/gpt_model.dart';
import 'package:chatgpt_chat/data/interfaces/local_storage_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageRepository extends LocalStorageModel {
  final SharedPreferences preferences;

  LocalStorageRepository(this.preferences);

  @override
  Future<void> saveApiToken(String token) async {
    await preferences.setString('apiToken', token);
  }

  @override
  Future<String?> getApiToken() async {
    String? value = preferences.getString('apiToken');
    return value;
  }

  @override
  Future<void> deleteThread(String id) async {
    var ids = await getThreads();
    ids.remove(id);
    await preferences.setStringList('threadIds', ids);
  }

  @override
  Future<List<String>> getThreads() async {
    var ids = preferences.getStringList('threadIds');
    return ids ?? [];
  }

  @override
  Future<void> saveThread(String id) async {
    var ids = await getThreads();
    if (!ids.contains(id)) {
      ids.add(id);
    }
    await preferences.setStringList('threadIds', ids);
  }

  @override
  Future<GptModel?> getChatModel() async {
    var model = preferences.getString('model');
    return GptModel.fromString(model ?? '');
  }

  @override
  Future<void> saveChatModel(GptModel model) async {
    await preferences.setString('model', model.toString());
  }

  @override
  Future<Duration?> getThreadsTtl() async {
    var days = preferences.getInt('threads_ttl');
    return days != null ? Duration(days: days) : null;
  }

  @override
  Future<void> saveThreadsTtl(Duration duration) async {
    await preferences.setInt('threads_ttl', duration.inDays);
  }
}
