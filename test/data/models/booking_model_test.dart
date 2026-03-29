import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/data/models/booking_model.dart';
import 'package:ttmastiff/data/models/course_model.dart';
import 'package:ttmastiff/data/models/session_model.dart';

Map<String, dynamic> _courseMap() {
  return {
    'id': 'c-1',
    'title': '瑜珈',
    'description': null,
    'price': 300,
    'default_start_time': '09:00:00',
    'default_end_time': '10:00:00',
    'image_url': null,
    'category': 'group',
    'is_published': true,
  };
}

Map<String, dynamic> _sessionMap() {
  return {
    'id': 'sess-1',
    'course_id': 'c-1',
    'start_time': '2026-07-01T09:00:00.000Z',
    'end_time': '2026-07-01T10:00:00.000Z',
    'max_capacity': 8,
    'coach_ids': <String>[],
    'table_ids': <String>[],
    'bookings': <Map<String, dynamic>>[
      {'count': 1},
    ],
    'courses': _courseMap(),
  };
}

Map<String, dynamic> _studentMap() {
  return {
    'id': 'stu-1',
    'parent_id': 'user-1',
    'name': '王小明',
    'birth_date': '2016-03-15',
    'is_primary': true,
  };
}

void main() {
  group('BookingModel.fromJson', () {
    test('完整欄位與巢狀 sessions、students', () {
      final json = <String, dynamic>{
        'id': 'book-1',
        'status': 'confirmed',
        'attendance_status': 'pending',
        'price_snapshot': 500,
        'student_id': 'stu-1',
        'session_id': 'sess-1',
        'created_at': '2026-06-15T08:00:00.000Z',
        'updated_at': '2026-06-15T08:01:00.000Z',
        'guest_name': null,
        'guest_phone': null,
        'sessions': _sessionMap(),
        'students': _studentMap(),
      };

      final b = BookingModel.fromJson(json);

      expect(b.id, 'book-1');
      expect(b.status, 'confirmed');
      expect(b.attendanceStatus, 'pending');
      expect(b.priceSnapshot, 500);
      expect(b.studentId, 'stu-1');
      expect(b.sessionId, 'sess-1');
      expect(b.session.id, 'sess-1');
      expect(b.session.course?.title, '瑜珈');
      expect(b.student?.name, '王小明');
      expect(b.isTeaching, false);
      expect(b.courseTitle, '瑜珈');
    });

    test('缺省 status、attendance_status、price_snapshot', () {
      final json = <String, dynamic>{
        'id': 'book-2',
        'student_id': 'stu-1',
        'session_id': 'sess-1',
        'created_at': '2026-06-15T08:00:00.000Z',
        'sessions': _sessionMap(),
        'students': _studentMap(),
      };

      final b = BookingModel.fromJson(json);

      expect(b.status, 'confirmed');
      expect(b.attendanceStatus, 'pending');
      expect(b.priceSnapshot, 0);
    });
  });

  group('BookingModel.fromCoachSession', () {
    test('標記 isTeaching 且 studentId 為教練 id', () {
      final course = CourseModel(
        id: 'c-1',
        title: '課',
        price: 0,
        defaultStartTime: DateTime(2026, 1, 1, 9, 0),
        defaultEndTime: DateTime(2026, 1, 1, 10, 0),
        category: 'group',
        isPublished: true,
      );
      final session = SessionModel(
        id: 'sess-x',
        courseId: 'c-1',
        startTime: DateTime(2026, 8, 1, 14, 0),
        endTime: DateTime(2026, 8, 1, 15, 0),
        maxCapacity: 6,
        course: course,
        studentNames: const [],
      );

      final b = BookingModel.fromCoachSession(session, 'coach-99');

      expect(b.isTeaching, true);
      expect(b.studentId, 'coach-99');
      expect(b.sessionId, 'sess-x');
      expect(b.priceSnapshot, 0);
      expect(b.id.startsWith('teach_'), true);
    });
  });
}
