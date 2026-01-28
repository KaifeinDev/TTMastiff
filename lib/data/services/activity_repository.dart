import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_model.dart';

class ActivityRepository {
  final SupabaseClient _supabase;

  ActivityRepository(this._supabase);

  /// 取得所有活動（依 order 排序）
  Future<List<ActivityModel>> getActivities({
    String? type,
    String? status,
  }) async {
    var query = _supabase.from('activities').select();

    if (type != null) {
      query = query.eq('type', type);
    }

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('order', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => ActivityModel.fromJson(json)).toList();
  }

  /// 取得單一活動
  Future<ActivityModel> getActivityById(String id) async {
    final response = await _supabase
        .from('activities')
        .select()
        .eq('id', id)
        .single();

    return ActivityModel.fromJson(response);
  }

  /// 新增活動
  Future<String> createActivity({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? image,
    required String type,
    required String status,
  }) async {
    // 取得該類型且相同狀態的最大 order
    final maxOrderRes = await _supabase
        .from('activities')
        .select('order')
        .eq('type', type)
        .eq('status', status)
        .order('order', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextOrder = 0;
    if (maxOrderRes != null) {
      nextOrder = (maxOrderRes['order'] as int) + 1;
    }

    final response = await _supabase.from('activities').insert({
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'image': image,
      'type': type,
      'order': nextOrder,
      'status': status,
    }).select('id').single();

    return response['id'] as String;
  }

  /// 更新活動
  Future<void> updateActivity(ActivityModel activity) async {
    await _supabase
        .from('activities')
        .update(activity.toJson())
        .eq('id', activity.id);
  }

  /// 更新活動狀態（上架/下架）
  Future<void> updateActivityStatus(String id, String status) async {
    await _supabase
        .from('activities')
        .update({'status': status})
        .eq('id', id);
  }

  /// 更新活動類型（輪播/近期活動）
  Future<void> updateActivityType(String id, String type) async {
    // 取得該類型且相同狀態的最大 order
    final maxOrderRes = await _supabase
        .from('activities')
        .select('order')
        .eq('type', type)
        .eq('status', 'active')
        .order('order', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextOrder = 0;
    if (maxOrderRes != null) {
      nextOrder = (maxOrderRes['order'] as int) + 1;
    }

    await _supabase.from('activities').update({
      'type': type,
      'order': nextOrder,
    }).eq('id', id);
  }

  /// 批次更新活動順序
  Future<void> updateActivitiesOrder(List<ActivityModel> activities) async {
    for (int i = 0; i < activities.length; i++) {
      await _supabase
          .from('activities')
          .update({'order': i})
          .eq('id', activities[i].id);
    }
  }

  /// 刪除活動
  Future<void> deleteActivity(String id) async {
    await _supabase.from('activities').delete().eq('id', id);
  }
}
