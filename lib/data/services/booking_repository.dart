import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';


class BookingRepository {
  final SupabaseClient _client;
  BookingRepository(this._client);

  Future<List<BookingModel>> fetchMyBookings() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('未登入');

    // 移除 location，加入 category 和 coaches
    final response = await _client
        .from('bookings')
        .select('''
          id,
          status,
          student:students!inner(name, parent_id),
          session:sessions(
            start_time, 
            end_time,
            coaches,
            course:courses(title, image_url, category)
          )
        ''')
        .eq('student.parent_id', user.id) 
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<void> cancelBooking(String bookingId) async {
    await _client.from('bookings').delete().eq('id', bookingId);
  }
}
