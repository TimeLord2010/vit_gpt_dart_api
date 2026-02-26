class Usage {
  final int inputTokens;
  final int outputTokens;
  final TokenDetails inputTokenDetails;
  final TokenDetails outputTokenDetails;

  Usage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.inputTokenDetails = const TokenDetails(),
    this.outputTokenDetails = const TokenDetails(),
  });

  factory Usage.fromMap(Map<String, dynamic> map) {
    return Usage(
      inputTokens: (map['input_tokens'] as num).toInt(),
      outputTokens: (map['output_tokens'] as num).toInt(),
      inputTokenDetails: TokenDetails.fromMap(map['input_token_details'] ?? {}),
      outputTokenDetails:
          TokenDetails.fromMap(map['output_token_details'] ?? {}),
    );
  }
}

class TokenDetails {
  final int textTokens;
  final int audioTokens;
  final TokenDetails? cachedTokensDetails;

  const TokenDetails({
    this.audioTokens = 0,
    this.textTokens = 0,
    this.cachedTokensDetails,
  });

  factory TokenDetails.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? cached = map['cached_tokens_details'];
    return TokenDetails(
      audioTokens: ((map['audio_tokens'] ?? 0) as num).toInt(),
      textTokens: ((map['text_tokens'] ?? 0) as num).toInt(),
      cachedTokensDetails: cached == null ? null : TokenDetails.fromMap(cached),
    );
  }
}
