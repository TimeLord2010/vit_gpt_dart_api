import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/factories/logger.dart';

/// Parses the json in the response that is being sent as a stream.
///
/// For this method to work you need to use:
/// ```dart
///  Options(responseType: ResponseType.stream);
/// ```
/// When making a request using Dio.
Stream<Map<String, dynamic>> getJsonStreamFromResponse(
  Response response, {
  Iterable<String> ignorePrefixes = const [],
}) async* {
  var data = response.data;
  Stream<Uint8List> stream = data.stream;
  String? lastChunk;
  await for (var chunk in stream) {
    var str = utf8.decode(chunk);
    var parts = str.split('\n');
    for (var part in parts) {
      part = part.trim();

      // Concatenating part with last chunk
      if (lastChunk != null) {
        part = lastChunk + part;
        lastChunk = null;
      }

      // Aborting part processing
      if (part.isEmpty || part == '[DONE]') {
        continue;
      }

      // Ignoring prefixes
      var ignored = false;
      for (var ignorePrefix in ignorePrefixes) {
        if (part.startsWith('$ignorePrefix: ')) {
          logger.warn('Ignored chunk part with prefix ($ignorePrefix): $part.');
          ignored = true;
          continue;
        }
      }
      if (ignored) {
        continue;
      }

      // Processing part
      if (part.startsWith('data: ')) {
        part = part.substring(6);
      }

      try {
        Map<String, dynamic> map = jsonDecode(part);
        logger.info('Processed chunk part: $part');
        yield map;
      } on FormatException {
        // Failed to parse json. Must be only part of the json.
        logger.warn('Failed to parse json: $part');
        lastChunk = part;
      }
    }
  }
}
