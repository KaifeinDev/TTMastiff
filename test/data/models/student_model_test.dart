import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/data/models/student_model.dart';

void main() {
  group('StudentModel.fromJson', () {
    test('正確解析所有欄位並套用預設值', () {
      final json = {
        'id': 's1',
        'parent_id': 'p1',
        'name': '王小明',
        'avatar_url': 'https://mock/avatar.png',
        'is_primary': true,
        // level 省略 -> 預設 beginner
        'birth_date': '2005-08-17',
        'gender': 'male',
        'medical_note': 'note',
        'points': 15,
      };
      final s = StudentModel.fromJson(json);
      expect(s.id, 's1');
      expect(s.parentId, 'p1');
      expect(s.name, '王小明');
      expect(s.avatarUrl, 'https://mock/avatar.png');
      expect(s.isPrimary, true);
      expect(s.level, 'beginner');
      expect(s.birthDate.year, 2005);
      expect(s.birthDate.month, 8);
      expect(s.birthDate.day, 17);
      expect(s.gender, 'male');
      expect(s.medicalNote, 'note');
      expect(s.points, 15);
    });

    test('缺少可選欄位時應給預設值', () {
      final json = {
        'id': 's2',
        'parent_id': 'p2',
        'name': '小華',
        // avatar_url 缺
        // is_primary 缺 -> false
        // level 缺 -> beginner
        'birth_date': '2010-01-05',
        // gender 缺
        // medical_note 缺
        // points 缺 -> 0
      };
      final s = StudentModel.fromJson(json);
      expect(s.avatarUrl, isNull);
      expect(s.isPrimary, false);
      expect(s.level, 'beginner');
      expect(s.gender, isNull);
      expect(s.medicalNote, isNull);
      expect(s.points, 0);
      expect(s.birthDate.year, 2010);
      expect(s.birthDate.month, 1);
      expect(s.birthDate.day, 5);
    });
  });
}

