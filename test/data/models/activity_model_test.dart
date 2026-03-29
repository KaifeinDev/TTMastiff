import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/data/models/activity_model.dart';

void main() {
  group('ActivityModel', () {
    test('fromJson 對應欄位與預設值', () {
      final m = ActivityModel.fromJson({
        'id': 'a-1',
        'title': '春遊',
        'description': '說明',
        'start_time': '2026-06-01T08:00:00.000Z',
        'end_time': '2026-06-01T18:00:00.000Z',
        'image': null,
        'type': 'carousel',
        'order': 2,
        'status': 'active',
        'notification_status': 'read',
        'created_at': '2026-05-01T00:00:00.000Z',
        'updated_at': '2026-05-02T00:00:00.000Z',
      });

      expect(m.id, 'a-1');
      expect(m.title, '春遊');
      expect(m.type, 'carousel');
      expect(m.order, 2);
      expect(m.notificationStatus, 'read');
      expect(m.updatedAt, isNotNull);
    });

    test('copyWith 覆寫單一欄位', () {
      final base = ActivityModel.fromJson({
        'id': 'x',
        'title': 'T',
        'description': 'D',
        'start_time': '2026-01-01T00:00:00.000Z',
        'end_time': '2026-01-02T00:00:00.000Z',
        'type': 'recent',
        'order': 0,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      final next = base.copyWith(notificationStatus: 'read');
      expect(next.notificationStatus, 'read');
      expect(next.title, 'T');
    });
  });
}
