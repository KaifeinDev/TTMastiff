import 'package:mocktail/mocktail.dart';
import 'package:ttmastiff/data/models/course_model.dart';
import 'package:ttmastiff/data/models/session_model.dart';
import 'package:ttmastiff/data/services/auth_manager.dart';
import 'package:ttmastiff/data/services/coach_repository.dart';
import 'package:ttmastiff/data/services/course_repository.dart';
import 'package:ttmastiff/data/services/session_repository.dart';

class MockCourseRepository extends Mock implements CourseRepository {}

class MockAuthManager extends Mock implements AuthManager {}

class MockSessionRepository extends Mock implements SessionRepository {}

class MockCoachRepository extends Mock implements CoachRepository {}

CourseModel sampleCourseModel({
  String id = 'course-1',
  String title = '測試課程',
  bool published = true,
}) {
  return CourseModel(
    id: id,
    title: title,
    description: '說明',
    price: 500,
    defaultStartTime: DateTime(2026, 1, 1, 10, 0),
    defaultEndTime: DateTime(2026, 1, 1, 11, 0),
    category: 'group',
    isPublished: published,
  );
}

SessionModel sampleSessionModel({
  required String id,
  required String courseId,
  required DateTime start,
  required DateTime end,
  CourseModel? course,
}) {
  return SessionModel(
    id: id,
    courseId: courseId,
    startTime: start,
    endTime: end,
    maxCapacity: 8,
    course: course,
    studentNames: const [],
  );
}

void registerCourseWidgetTestFallbacks() {
  registerFallbackValue(1);
}
