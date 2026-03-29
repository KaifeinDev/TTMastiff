import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/auth_manager.dart';
import 'package:ttmastiff/data/services/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockUser extends Mock implements User {}

void main() {
  group('AuthManager', () {
    late MockAuthRepository repo;
    late AuthManager manager;

    setUp(() {
      repo = MockAuthRepository();
      manager = AuthManager(repo);
    });

    test('signIn 成功後更新 role 與 loading 狀態', () async {
      // 模擬登入與回傳的 currentUser.id
      when(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async {});
      final user = MockUser();
      when(() => user.id).thenReturn('uid1');
      when(() => repo.currentUser).thenReturn(user);
      when(() => repo.fetchUserRole('uid1')).thenAnswer((_) async => 'admin');

      expect(manager.isLoading, true); // 初始為 true，未呼叫 init 也可被 signIn 覆蓋
      await manager.signIn(email: 'mock_u@u.com', password: 'mock_pw');
      expect(manager.isLoading, false);
      expect(manager.isAdmin, true);
      expect(manager.isCoach, false);
      expect(manager.isStaff, true);
    });

    test('signIn 失敗會拋出 Exception 並重置 loading', () async {
      when(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('boom'));
      when(() => repo.currentUser).thenReturn(null);

      expect(() => manager.signIn(email: 'mock_u@u.com', password: 'mock_pw'), throwsA(isA<Exception>()));
      expect(manager.isLoading, false);
    });

    test('signOut 會清空狀態並呼叫 repo.signOut', () async {
      when(() => repo.signOut()).thenAnswer((_) async {});
      // 先假設為 admin
      when(() => repo.fetchUserRole(any())).thenAnswer((_) async => 'admin');
      // 模擬已經有 admin 的狀態
      when(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async {});
      final user = MockUser();
      when(() => user.id).thenReturn('mock_u');
      when(() => repo.currentUser).thenReturn(user);
      await manager.signIn(email: 'mock_u@u.com', password: 'mock_pw');
      expect(manager.isAdmin, true);

      await manager.signOut();
      expect(manager.isAdmin, false);
      verify(() => repo.signOut()).called(1);
    });
  });
}

