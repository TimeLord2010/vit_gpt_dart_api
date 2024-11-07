import 'package:test/test.dart';
import 'package:vit_gpt_dart_api/usecases/object/string/split_preserving_separator.dart';

void main() {
  test('split preserving separator', () async {
    Pattern separator = RegExp(r'\.|\?|!');
    var result = splitPreservingSeparator('Ok! My name is Leia.', separator);
    expect(result, ['Ok!', 'My name is Leia.']);
  });
}
