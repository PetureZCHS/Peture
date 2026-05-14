import 'package:flutter_test/flutter_test.dart';
import 'package:my_pet/shared/utils/analytics_payload_sanitizer.dart';

void main() {
  group('sanitizeAnalyticsProperties', () {
    test('removes sensitive keys recursively', () {
      final result = sanitizeAnalyticsProperties({
        'button_id': 'share',
        'phone': '13800138000',
        'nested': {
          'email': 'user@example.com',
          'source': 'diary',
        },
      });

      expect(result['button_id'], 'share');
      expect(result.containsKey('phone'), isFalse);
      expect(result['nested'], {'source': 'diary'});
    });

    test('bounds strings and arrays', () {
      final result = sanitizeAnalyticsProperties({
        'long': 'x' * 300,
        'items': List.generate(25, (index) => index),
      });

      expect((result['long'] as String).length, 240);
      expect(result['items'], hasLength(20));
    });
  });
}
