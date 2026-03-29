import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/data/models/session_model.dart';

Map<String, dynamic> _courseMap({String id = 'c-1'}) {
  return {
    'id': id,
    'title': '課程',
    'description': null,
    'price': 100,
    'default_start_time': '10:00:00',
    'default_end_time': '11:00:00',
    'image_url': null,
    'category': 'group',
    'is_published': true,
  };
}

void main() {
  group('SessionModel.fromJson', () {
    test('完整欄位與巢狀 courses', () {
      final json = <String, dynamic>{
        'id': 's-1',
        'course_id': 'c-1',
        'start_time': '2026-06-01T10:00:00.000Z',
        'end_time': '2026-06-01T11:30:00.000Z',
        'location': '教室A',
        'max_capacity': 10,
        'coach_ids': <String>['coach-1'],
        'coach_name': '張教練',
        'table_ids': <String>[],
        'bookings': <Map<String, dynamic>>[
          {'count': 4},
        ],
        'courses': _courseMap(),
      };

      final m = SessionModel.fromJson(json);

      expect(m.id, 's-1');
      expect(m.courseId, 'c-1');
      expect(m.location, '教室A');
      expect(m.maxCapacity, 10);
      expect(m.coachIds, ['coach-1']);
      expect(m.coachName, '張教練');
      expect(m.course?.title, '課程');
      expect(m.bookingsCount, 4);
      expect(m.studentNames, isEmpty);
    });

    test('bookings 為詳細列表時以 confirmed 名單計算人數', () {
      final json = <String, dynamic>{
        'id': 's-2',
        'course_id': 'c-1',
        'start_time': '2026-06-01T10:00:00.000Z',
        'end_time': '2026-06-01T11:00:00.000Z',
        'max_capacity': 8,
        'coach_ids': <String>[],
        'table_ids': <String>[],
        'bookings': <Map<String, dynamic>>[
          {
            'status': 'confirmed',
            'students': {'name': '甲'},
          },
          {
            'status': 'confirmed',
            'students': {'name': '乙'},
          },
          {
            'status': 'cancelled',
            'students': {'name': '丙'},
          },
        ],
        'courses': _courseMap(),
      };

      final m = SessionModel.fromJson(json);

      expect(m.bookingsCount, 2);
      expect(m.studentNames, ['甲', '乙']);
    });

    test('table_ids 可解析並略過 null 元素', () {
      final json = <String, dynamic>{
        'id': 's-3',
        'course_id': 'c-1',
        'start_time': '2026-06-01T10:00:00.000Z',
        'end_time': '2026-06-01T11:00:00.000Z',
        'max_capacity': 4,
        'coach_ids': <String>[],
        'table_ids': <dynamic>['t1', null, 't2'],
        'bookings': <Map<String, dynamic>>[
          {'count': 0},
        ],
        'courses': _courseMap(),
      };

      final m = SessionModel.fromJson(json);
      expect(m.tableIds, ['t1', 't2']);
    });

    test('缺省 max_capacity 時預設為 4', () {
      final json = <String, dynamic>{
        'id': 's-4',
        'course_id': 'c-1',
        'start_time': '2026-06-01T10:00:00.000Z',
        'end_time': '2026-06-01T11:00:00.000Z',
        'coach_ids': <String>[],
        'table_ids': <String>[],
        'bookings': <Map<String, dynamic>>[
          {'count': 0},
        ],
        'courses': _courseMap(),
      };

      final m = SessionModel.fromJson(json);
      expect(m.maxCapacity, 4);
    });
  });
}
