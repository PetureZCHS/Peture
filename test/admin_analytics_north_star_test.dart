import 'package:flutter_test/flutter_test.dart';

import 'package:my_pet/features/admin_analytics/presentation/admin_analytics_app.dart';

void main() {
  test('north star metrics are normalized from dashboard payload', () {
    final metrics = normalizeNorthStarMetrics({
      'weekly_value_recording_users': 7,
      'weekly_active_pet_profiles': 4,
      'weekly_pet_memories_saved': 12,
      'active_pet_profiles_approximate': true,
    });

    expect(metrics.valueRecordingUsers, 7);
    expect(metrics.activePetProfiles, 4);
    expect(metrics.petMemoriesSaved, 12);
    expect(metrics.activePetProfilesApproximate, isTrue);
  });

  test('north star metrics fall back to zeroes for missing payload', () {
    final metrics = normalizeNorthStarMetrics(null);

    expect(metrics.valueRecordingUsers, 0);
    expect(metrics.activePetProfiles, 0);
    expect(metrics.petMemoriesSaved, 0);
    expect(metrics.activePetProfilesApproximate, isFalse);
  });
}
