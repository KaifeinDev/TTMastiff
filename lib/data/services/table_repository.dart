import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/table_model.dart';

class TableRepository {
  final SupabaseClient _supabase;

  TableRepository(this._supabase);

  /// 取得所有桌次 (依照 sort_order 排序)
  Future<List<TableModel>> getTables() async {
    final response = await _supabase
        .from('tables')
        .select()
        .order('sort_order', ascending: true); // 重點：依照順序抓取

    final data = response as List<dynamic>;
    return data.map((json) => TableModel.fromJson(json)).toList();
  }

  /// 新增桌次
  Future<void> createTable(String name, int capacity, {String? remarks}) async {
    // 先抓目前最大的 sort_order，新增的排在最後
    final maxOrderRes = await _supabase
        .from('tables')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextOrder = 0;
    if (maxOrderRes != null) {
      nextOrder = (maxOrderRes['sort_order'] as int) + 1;
    }

    await _supabase.from('tables').insert({
      'name': name,
      'capacity': capacity,
      'is_active': true,
      'sort_order': nextOrder,
      'remarks': remarks,
    });
  }

  /// 更新桌次資訊
  Future<void> updateTable(TableModel table) async {
    await _supabase.from('tables').update(table.toJson()).eq('id', table.id);
  }

  /// 刪除桌次
  /// ⚠️ 注意：如果有 Sessions 綁定此桌次，Supabase 可能會報錯 (Foreign Key Constraint)
  /// 建議用 try-catch 包裹，失敗時提示使用者改用「停用」
  Future<void> deleteTable(String id) async {
    await _supabase.from('tables').delete().eq('id', id);
  }

  /// 批次更新排序 (當使用者拖拉列表後呼叫)
  /// 目前關閉這個功能 (unnecessary)
  /*
  Future<void> updateTableOrder(List<TableModel> tables) async {
    // 這裡為了簡單，我們逐筆更新。若桌數很多(>50)可考慮寫成 Postgres Function
    // 但球桌通常不多，這樣寫沒問題。
    for (int i = 0; i < tables.length; i++) {
      await _supabase
          .from('tables')
          .update({'sort_order': i})
          .eq('id', tables[i].id);
    }
  }
  */
}
