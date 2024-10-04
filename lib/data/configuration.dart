import 'dart:io';

class VitGptConfiguration {
  static Directory? _internalFilesDirectory;

  static Directory get internalFilesDirectory {
    var dir = _internalFilesDirectory;
    if (dir == null) {
      throw Exception('Not initialized: internal files directory');
    }
    return dir;
  }

  static set internalFilesDirectory(Directory directory) {
    _internalFilesDirectory = directory;
  }
}
