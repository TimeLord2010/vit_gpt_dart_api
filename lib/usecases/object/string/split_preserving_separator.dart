/// Splits the input text into segments based on the specified delimiter pattern,
/// while ensuring that each segment includes the delimiter at its end.
///
/// This method finds segments by locating delimiter patterns (e.g., punctuation marks)
/// and splits the string accordingly, preserving the delimiter within the resulting segments.
///
/// Example:
/// ```dart
/// String text = "Hello! How are you? I hope you're doing well.";
/// Pattern pattern = RegExp(r'[.!?]');
/// List<String> result = splitPreservingSeparator(text, pattern);
/// // result: ['Hello!', 'How are you?', "I hope you're doing well."]
/// ```
///
/// - text: The input string to split.
/// - separatorPattern: The pattern to recognize as the end of a segment (e.g., punctuation).
///
/// Returns a list of string segments with delimiters preserved at the end of each segment.
List<String> splitPreservingSeparator(String text, Pattern separatorPattern) {
  List<String> result = [];
  var currentSection = StringBuffer();

  // Use a regular expression to find all matches of the separator in the text
  var matches = separatorPattern.allMatches(text);

  int lastMatchEnd = 0;

  for (var match in matches) {
    // Add everything from the last end position to the current match as a separate part
    currentSection.write(text.substring(lastMatchEnd, match.end));
    result.add(currentSection.toString().trim());
    currentSection.clear();

    // Update the last match end position
    lastMatchEnd = match.end;
  }

  // Add remaining text part after the last match
  if (lastMatchEnd < text.length) {
    currentSection.write(text.substring(lastMatchEnd));
    result.add(currentSection.toString().trim());
  }

  return result;
}
