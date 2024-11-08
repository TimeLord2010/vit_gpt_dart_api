import 'message.dart';

class Conversation {
  String? id;
  DateTime? createdAt;
  List<Message> messages = [];
  Map<String, String>? metadata;

  Conversation({
    this.id,
    this.createdAt,
    this.metadata,
  });

  String? get title {
    return metadata?['title'];
  }

  set title(String? title) {
    if (metadata == null) {
      if (title == null) {
        return;
      }
      metadata = {};
    }
    if (title == null) {
      metadata?.remove('title');
      return;
    }
    metadata!['title'] = title;
  }

  DateTime? get updatedAt {
    var iso = metadata?['updated_at'];
    if (iso == null) return null;
    return DateTime.parse(iso).toLocal();
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    int createdAt = map['created_at'];
    Map<String, dynamic> map2 = map['metadata'];
    return Conversation(
      id: map['id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      metadata: Map<String, String>.from(map2),
    );
  }

  void _update(String key, String value) {
    metadata ??= {};
    metadata![key] = value;
  }

  /// Updates the last update date if the day stored currently is more than 5
  /// minutes old compared to now.
  bool recordUpdate() {
    var lastUpdate = updatedAt;
    var now = DateTime.now();

    if (lastUpdate != null) {
      var diff = now.difference(lastUpdate).inMinutes;
      if (diff < 5) {
        return false;
      }
    }

    _update('updated_at', now.toUtc().toIso8601String());

    return true;
  }
}
