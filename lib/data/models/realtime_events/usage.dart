class Usage {
  final int inputTokens;
  final int outputTokens;
  final TokenDetails inputTokenDetails;
  final TokenDetails outputTokenDetails;

  Usage({
    required this.inputTokens,
    required this.outputTokens,
    required this.inputTokenDetails,
    required this.outputTokenDetails,
  });

  factory Usage.fromMap(Map<String, dynamic> map) {
    return Usage(
      inputTokens: (map['input_tokens'] as num).toInt(),
      outputTokens: (map['output_tokens'] as num).toInt(),
      inputTokenDetails: TokenDetails.fromMap(map['input_token_details']),
      outputTokenDetails: TokenDetails.fromMap(map['output_token_details']),
    );
  }
}

class TokenDetails {
  final int textTokens;
  final int audioTokens;

  TokenDetails({
    required this.audioTokens,
    required this.textTokens,
  });

  factory TokenDetails.fromMap(Map<String, dynamic> map) {
    return TokenDetails(
      audioTokens: ((map['audioTokens'] ?? 0) as num).toInt(),
      textTokens: ((map['textTokens'] ?? 0) as num).toInt(),
    );
  }
}
