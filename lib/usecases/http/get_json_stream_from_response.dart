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
  Uint8List? lastChunk;
  String? lastPart;
  await for (var chunk in stream) {
    try {
      // Handling incomplete uft8 parts.
      //
      // Sometimes the chunk is missing a part of a symbol.
      if (lastChunk != null) {
        chunk.insertAll(0, lastChunk);
      }

      // Decoding bytes to text.
      String str;
      try {
        str = utf8.decode(chunk);
      } on FormatException {
        logger.warn('Failed at utf8 decoding. Attempting raw string decode');
        str = String.fromCharCodes(chunk);
      }

      // If decode worked, then we can dismiss the last chunk.
      if (lastChunk != null) {
        logger.info('Able to read the chunk after concatenation.');
      }
      lastChunk = null;

      // Spliting by new lines but don't remember why.
      var parts = str.split('\n');
      for (var part in parts) {
        part = part.trim();

        // Concatenating part with last chunk
        if (lastPart != null) {
          part = lastPart + part;
          lastPart = null;
        }

        // Aborting part processing
        if (part.isEmpty || part.trim() == '[DONE]') {
          continue;
        }

        // Ignoring prefixes
        var ignored = false;
        for (var ignorePrefix in ignorePrefixes) {
          if (part.startsWith('$ignorePrefix: ')) {
            logger
                .warn('Ignored chunk part with prefix ($ignorePrefix): $part.');
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

        // Making the json valid
        // The [part] variable can become invalid, if the stream has cut on the
        // middle of a [ignorePrefixes].
        if (!part.startsWith('{')) {
          var index = part.indexOf('{');
          if (index >= 0) {
            part = part.substring(index);
          }
        }

        try {
          Map<String, dynamic> map = jsonDecode(part);
          logger.info('Processed chunk part: $part');
          yield map;
        } on FormatException {
          // Failed to parse json. Must be only part of the json.
          logger.warn('Failed to parse json: $part');
          lastPart = part;
        }
      }
    } on FormatException {
      // Problem in the uft8.decode call.
      //
      // This must be due to incomplete chunk that is not parsable.
      logger.warn(
          'Problem in the utf8.decode call when fetching stream. Saving the incomplete chunk');
      if (lastChunk == null) {
        lastChunk = chunk;
      } else {
        lastChunk.addAll(chunk);
      }
    }
  }
}
