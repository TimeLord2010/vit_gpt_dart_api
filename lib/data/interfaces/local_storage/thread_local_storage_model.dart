mixin ThreadLocalStorageModel {
  // MARK: Thread ids

  Future<List<String>> getThreads();

  Future<void> deleteThread(String id);

  Future<void> saveThread(String id);

  Future<String?> getThreadTitle(String id);

  Future<void> saveThreadTitle(String id, String title);

  /// Should produce a map of thread titles where the keys are the ids and
  /// the values are the titles.
  Future<Map<String, String>> getThreadsTitle(Iterable<String> ids);
}
