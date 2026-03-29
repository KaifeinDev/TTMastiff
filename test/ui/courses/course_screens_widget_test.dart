import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ttmastiff/data/models/course_model.dart';
import 'package:ttmastiff/ui/admin/courses/course_detail_screen.dart';
import 'package:ttmastiff/ui/admin/courses/course_list_screen.dart';
import 'package:ttmastiff/ui/screens/courses_screen.dart';

import '../../support/course_widget_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerCourseWidgetTestFallbacks();
    await initializeDateFormatting('zh_TW', null);
  });

  group('CoursesScreen', () {
    late MockCourseRepository mockRepo;

    setUp(() {
      mockRepo = MockCourseRepository();
    });

    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('載入中應顯示進度指示器', (tester) async {
      final completer = Completer<List<CourseModel>>();
      when(() => mockRepo.fetchCoursesByWeekday(any())).thenAnswer(
        (_) => completer.future,
      );

      await tester.pumpWidget(
        wrap(
          CoursesScreen(
            courseRepository: mockRepo,
            membershipLoader: () async => 'beginner',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(<CourseModel>[]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('無課程時顯示空狀態文案', (tester) async {
      when(() => mockRepo.fetchCoursesByWeekday(any())).thenAnswer(
        (_) async => [],
      );

      await tester.pumpWidget(
        wrap(
          CoursesScreen(
            courseRepository: mockRepo,
            membershipLoader: () async => 'beginner',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('沒有安排課程'), findsOneWidget);
    });

    testWidgets('讀取失敗時顯示錯誤與重試', (tester) async {
      when(() => mockRepo.fetchCoursesByWeekday(any())).thenThrow(
        Exception('network'),
      );

      await tester.pumpWidget(
        wrap(
          CoursesScreen(
            courseRepository: mockRepo,
            membershipLoader: () async => 'beginner',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('讀取失敗'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
    });

    testWidgets('有課程時列表顯示課程標題', (tester) async {
      final course = sampleCourseModel(title: '團體瑜珈');
      when(() => mockRepo.fetchCoursesByWeekday(any())).thenAnswer(
        (_) async => [course],
      );

      await tester.pumpWidget(
        wrap(
          CoursesScreen(
            courseRepository: mockRepo,
            membershipLoader: () async => 'beginner',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('團體瑜珈'), findsOneWidget);
    });
  });

  group('CourseListScreen', () {
    late MockCourseRepository mockRepo;
    late MockAuthManager mockAuth;

    setUp(() {
      mockRepo = MockCourseRepository();
      mockAuth = MockAuthManager();
    });

    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('載入中顯示進度指示器', (tester) async {
      final completer = Completer<List<CourseModel>>();
      when(() => mockRepo.getCourses()).thenAnswer(
        (_) => completer.future,
      );
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(
        wrap(
          CourseListScreen(
            courseRepository: mockRepo,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(<CourseModel>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('分頁籤應有「上架中」與「已封存」', (tester) async {
      when(() => mockRepo.getCourses()).thenAnswer((_) async => []);
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(
        wrap(
          CourseListScreen(
            courseRepository: mockRepo,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('上架中'), findsOneWidget);
      expect(find.text('已封存'), findsOneWidget);
    });

    testWidgets('管理員顯示編輯與封存按鈕', (tester) async {
      final published = sampleCourseModel(id: 'p1', published: true);
      when(() => mockRepo.getCourses()).thenAnswer((_) async => [published]);
      when(() => mockAuth.isAdmin).thenReturn(true);

      await tester.pumpWidget(
        wrap(
          CourseListScreen(
            courseRepository: mockRepo,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });

    testWidgets('非管理員不顯示操作按鈕', (tester) async {
      final published = sampleCourseModel(id: 'p1', published: true);
      when(() => mockRepo.getCourses()).thenAnswer((_) async => [published]);
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(
        wrap(
          CourseListScreen(
            courseRepository: mockRepo,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('已封存分頁空狀態', (tester) async {
      when(() => mockRepo.getCourses()).thenAnswer((_) async => []);
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(
        wrap(
          CourseListScreen(
            courseRepository: mockRepo,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('已封存'));
      await tester.pumpAndSettle();

      expect(find.text('沒有已封存的課程'), findsOneWidget);
    });
  });

  group('AdminCourseDetailScreen', () {
    late MockCourseRepository mockCourse;
    late MockSessionRepository mockSession;
    late MockCoachRepository mockCoach;
    late MockAuthManager mockAuth;

    setUp(() {
      mockCourse = MockCourseRepository();
      mockSession = MockSessionRepository();
      mockCoach = MockCoachRepository();
      mockAuth = MockAuthManager();
    });

    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('無 initialData 時先顯示全頁載入', (tester) async {
      final completer = Completer<CourseModel>();
      when(() => mockCourse.getCourseById(any())).thenAnswer(
        (_) => completer.future,
      );
      when(() => mockSession.getSessionsByCourse(any())).thenAnswer(
        (_) async => [],
      );
      when(() => mockCoach.getCoaches()).thenAnswer((_) async => []);
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(
        wrap(
          AdminCourseDetailScreen(
            courseId: 'c1',
            courseRepository: mockCourse,
            sessionRepository: mockSession,
            coachRepository: mockCoach,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(sampleCourseModel());
      await tester.pumpAndSettle();
    });

    testWidgets('有 initialData 時顯示標題與兩個分頁', (tester) async {
      final course = sampleCourseModel(title: '管理後台課程');
      when(() => mockSession.getSessionsByCourse(any())).thenAnswer(
        (_) async => [],
      );
      when(() => mockCoach.getCoaches()).thenAnswer((_) async => []);
      when(() => mockAuth.isAdmin).thenReturn(true);

      await tester.pumpWidget(
        wrap(
          AdminCourseDetailScreen(
            courseId: course.id,
            initialData: course,
            courseRepository: mockCourse,
            sessionRepository: mockSession,
            coachRepository: mockCoach,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('管理後台課程'), findsOneWidget);
      expect(find.text('即將開始'), findsOneWidget);
      expect(find.text('歷史紀錄'), findsOneWidget);
    });

    testWidgets('即將開始列表有場次時顯示內容', (tester) async {
      final course = sampleCourseModel(title: '課A');
      final futureSession = sampleSessionModel(
        id: 's1',
        courseId: course.id,
        start: DateTime(2026, 12, 15, 14, 0),
        end: DateTime(2026, 12, 15, 15, 0),
        course: course,
      );

      when(() => mockSession.getSessionsByCourse(any())).thenAnswer(
        (_) async => [futureSession],
      );
      when(() => mockCoach.getCoaches()).thenAnswer((_) async => []);
      when(() => mockAuth.isAdmin).thenReturn(true);

      await tester.pumpWidget(
        wrap(
          AdminCourseDetailScreen(
            courseId: course.id,
            initialData: course,
            courseRepository: mockCourse,
            sessionRepository: mockSession,
            coachRepository: mockCoach,
            authManager: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('尚無學員報名'), findsWidgets);
      expect(find.text('刪除'), findsOneWidget);
    });
  });
}
