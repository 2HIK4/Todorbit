import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/contributors.dart';

void main() {
  test('registry accepts reviewed contribution types', () {
    const source =
        '''{"version":1,"community":[{"name":"Ada","title":"High contrast theme","type":"themes","description":"Adds accessible colors","profile":"https://example.com/ada"}]}''';
    final registry = ContributorRegistry.parse(source);
    expect(registry.community.single.type, ContributionType.themes);
  });

  test('registry rejects unknown type and unsafe profile link', () {
    expect(
      () => ContributorRegistry.parse(
        '''{"version":1,"community":[{"name":"A","title":"B","type":"unknown","description":"C"}]}''',
      ),
      throwsFormatException,
    );
    expect(
      () => ContributorRegistry.parse(
        '''{"version":1,"community":[{"name":"A","title":"B","type":"themes","description":"C","profile":"javascript:bad"}]}''',
      ),
      throwsFormatException,
    );
  });
}
