enum AudioFormat {
  mp3,

  // For internet streaming and communication, low latency.
  opus,

  // For digital audio compression, preferred by YouTube, Android, iOS.
  aac,

  // For lossless audio compression, favored by audio enthusiasts for archiving.
  flac,

  // Uncompressed WAV audio, suitable for low-latency applications to avoid decoding overhead.
  wav,

  // Similar to WAV but containing the raw samples in 24kHz (16-bit signed, low-endian), without the header.
  pcm,
}
