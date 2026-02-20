import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_encoder_interface.dart';

/// Audio encoder implementation for Android and iOS platforms using FFmpeg
class AudioEncoder implements AudioEncoderInterface {
  @override
  Future<Uint8List> encodePcmToMp3({
    required Uint8List pcmData,
    required int sampleRate,
    required int numChannels,
  }) async {
    Directory tempDir;
    String inputPath = '';
    String outputPath = '';

    try {
      // Get temporary directory
      tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      inputPath = '${tempDir.path}/audio_input_$timestamp.pcm';
      outputPath = '${tempDir.path}/audio_output_$timestamp.mp3';

      // Write PCM data to temporary file
      final inputFile = File(inputPath);
      await inputFile.writeAsBytes(pcmData);

      // Build FFmpeg command
      // -f s16le: input format is signed 16-bit little-endian PCM
      // -ar: audio sample rate
      // -ac: number of audio channels
      // -i: input file
      // -codec:a libmp3lame: use LAME MP3 encoder
      // -b:a 128k: bitrate 128 kbps
      final command = '-f s16le -ar $sampleRate -ac $numChannels '
          '-i "$inputPath" -codec:a libmp3lame -b:a 128k "$outputPath"';

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        throw Exception(
          'FFmpeg encoding failed with return code $returnCode\n'
          'Output: $output',
        );
      }

      // Read the MP3 file
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw Exception('MP3 output file was not created');
      }

      final mp3Data = await outputFile.readAsBytes();

      // Clean up temporary files
      await inputFile.delete();
      await outputFile.delete();

      return mp3Data;
    } catch (e) {
      // Clean up on error
      try {
        if (inputPath.isNotEmpty) {
          final inputFile = File(inputPath);
          if (await inputFile.exists()) {
            await inputFile.delete();
          }
        }
        if (outputPath.isNotEmpty) {
          final outputFile = File(outputPath);
          if (await outputFile.exists()) {
            await outputFile.delete();
          }
        }
      } catch (_) {
        // Ignore cleanup errors
      }

      throw Exception('Failed to encode PCM to MP3: $e');
    }
  }
}
