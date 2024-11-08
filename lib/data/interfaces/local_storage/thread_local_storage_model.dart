mixin ThreadLocalStorageModel {
  // MARK: Thread ids

  Future<List<String>> getThreads();

  Future<void> deleteThread(String id);

  Future<void> saveThread(String id);

  Future<String?> getThreadTitle(String id);

  Future<void> saveThreadTitle(String id, String title);
}
