import 'package:flutter_test/flutter_test.dart';
import 'package:my_pet/services/analytics_service.dart';
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

  group('reconcileAnalyticsQueueAfterFlush', () {
    test('preserves events enqueued while a flush is in flight', () {
      final sentBatch = [
        {
          'client_event_id': 'old-1',
          'event_name': 'app_open',
        },
        {
          'client_event_id': 'old-2',
          'event_name': 'page_view',
        },
      ];
      final latestQueue = [
        ...sentBatch,
        {
          'client_event_id': 'new-1',
          'event_name': 'feature_entry',
        },
      ];

      final remaining = reconcileAnalyticsQueueAfterFlush(
        latestQueue,
        sentBatch,
      );

      expect(remaining, hasLength(1));
      expect(remaining.single['client_event_id'], 'new-1');
    });

    test('falls back for legacy queued events without client_event_id', () {
      final sentBatch = [
        {'event_name': 'app_open'},
      ];
      final latestQueue = [
        {'event_name': 'app_open'},
        {
          'client_event_id': 'new-1',
          'event_name': 'page_view',
        },
      ];

      final remaining = reconcileAnalyticsQueueAfterFlush(
        latestQueue,
        sentBatch,
      );

      expect(remaining, hasLength(1));
      expect(remaining.single['client_event_id'], 'new-1');
    });
  });

  group('appendAnalyticsEventToQueue', () {
    test('preserves existing queued events and appends the new event', () {
      final result = appendAnalyticsEventToQueue(
        [
          {'client_event_id': 'old-1'},
        ],
        {'client_event_id': 'new-1'},
        maxQueueSize: 10,
      );

      expect(result.map((event) => event['client_event_id']), [
        'old-1',
        'new-1',
      ]);
    });

    test('keeps the newest events when the queue exceeds the size limit', () {
      final result = appendAnalyticsEventToQueue(
        [
          {'client_event_id': 'old-1'},
          {'client_event_id': 'old-2'},
        ],
        {'client_event_id': 'new-1'},
        maxQueueSize: 2,
      );

      expect(result.map((event) => event['client_event_id']), [
        'old-2',
        'new-1',
      ]);
    });
  });
}
