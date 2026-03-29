import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/data/models/course_model.dart';

void main() {
  group('CourseModel.fromJson', () {
    test('完整欄位時正確對應所有屬性', () {
      final json = <String, dynamic>{
        'id': 'c-1',
        'title': '測試課程',
        'description': '說明文字',
        'price': 500,
        'default_start_time': '09:30:00',
        'default_end_time': '10:45:00',
        'image_url': 'https://example.com/a.png',
        'category': 'personal',
        'is_published': true,
      };

      final m = CourseModel.fromJson(json);

      expect(m.id, 'c-1');
      expect(m.title, '測試課程');
      expect(m.description, '說明文字');
      expect(m.price, 500);
      expect(m.imageUrl, 'https://example.com/a.png');
      expect(m.category, 'personal');
      expect(m.isPublished, true);
      expect(m.defaultStartTime.hour, 9);
      expect(m.defaultStartTime.minute, 30);
      expect(m.defaultEndTime.hour, 10);
      expect(m.defaultEndTime.minute, 45);
    });

    test('缺省欄位時套用預設：title、price、category、is_published', () {
      final json = <String, dynamic>{
        'id': 'c-2',
        'default_start_time': '12:00:00',
        'default_end_time': '13:00:00',
      };

      final m = CourseModel.fromJson(json);

      expect(m.title, '未命名課程');
      expect(m.price, 0);
      expect(m.category, 'group');
      expect(m.isPublished, false);
      expect(m.description, isNull);
    });

    test('description 與 image_url 可為 null', () {
      final json = <String, dynamic>{
        'id': 'c-3',
        'title': 'X',
        'price': 1,
        'default_start_time': '08:00:00',
        'default_end_time': '09:00:00',
        'category': 'group',
        'is_published': false,
      };

      final m = CourseModel.fromJson(json);

      expect(m.description, isNull);
      expect(m.imageUrl, isNull);
    });
  });
}
