import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/coach_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class TestableCoachRepository extends CoachRepository {
  TestableCoachRepository(SupabaseClient c, {this.onSelect}) : super(c);
  final Future<dynamic> Function()? onSelect;
  @override
  Future<List<Map<String, dynamic>>> getCoaches() async {
    if (onSelect != null) {
      final data = await onSelect!();
      return List<Map<String, dynamic>>.from(data);
    }
    return super.getCoaches();
  }
}

void main() {
  group('CoachRepository', () {
    late MockSupabaseClient client;

    setUp(() {
      client = MockSupabaseClient();
    });

    test('getCoaches 會回傳教練/管理員的 id 與 full_name', () async {
      final repo2 = TestableCoachRepository(
        client,
        onSelect: () async => [
          {'id': 'c1', 'full_name': '教練甲'},
          {'id': 'a1', 'full_name': '管理員乙'},
        ],
      );

      final coaches = await repo2.getCoaches();
      expect(coaches, isA<List<Map<String, dynamic>>>());
      expect(coaches.length, 2);
      expect(coaches[0]['id'], 'c1');
      expect(coaches[0]['full_name'], '教練甲');
      expect(coaches[1]['id'], 'a1');
      expect(coaches[1]['full_name'], '管理員乙');
    });

    test('getCoaches 當 Supabase 丟錯時向上拋出', () async {
      final repo2 = TestableCoachRepository(
        client,
        onSelect: () async => throw Exception('db error'),
      );
      expect(() => repo2.getCoaches(), throwsA(isA<Exception>()));
    });
  });
}

