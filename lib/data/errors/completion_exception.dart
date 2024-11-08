class CompletionException extends Error {
  final String? code;
  final String? message;

  CompletionException(this.code, this.message);
}
