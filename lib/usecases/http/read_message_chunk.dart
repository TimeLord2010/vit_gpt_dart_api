/// Processes a json that follows this schema:
/// ```ts
/// {
///   "choices":[
///     {
///       "index":0,
///       "delta":{
///         "role":"assistant",
///         "content":"",
///         "refusal":null
///       },
///       "logprobs":null,
///       "finish_reason":null
///     }
///   ]
/// }
/// ```
String? readMessageChunk(Map<String, dynamic> json) {
  List choices = json['choices'];
  Map<String, dynamic> choice = choices[0];
  Map<String, dynamic> delta = choice['delta'];
  String? content = delta['content'];
  return content;
}
