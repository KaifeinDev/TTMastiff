import 'package:supabase_flutter/supabase_flutter.dart';

class CoachRepository {
  final SupabaseClient _supabase;
  CoachRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getCoaches() async {
    final data = await _supabase
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'coach');
    return List<Map<String, dynamic>>.from(data);
  }
}