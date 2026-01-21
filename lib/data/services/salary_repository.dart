import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payroll_model.dart';
import '../models/work_shift_model.dart';
import '../models/staff_detail_model.dart';

class SalaryRepository {
  final SupabaseClient _supabase;
  SalaryRepository(this._supabase);

  /// 1. 取得某月份的所有「已結算薪資單」
  Future<List<PayrollModel>> getPayrolls(int year, int month) async {
    final res = await _supabase
        .from('payrolls')
        .select()
        .eq('year', year)
        .eq('month', month);
    return (res as List).map((e) => PayrollModel.fromJson(e)).toList();
  }

  /// 2. 取得某員工的詳細設定 (時薪)
  Future<StaffDetailModel?> getStaffDetail(String staffId) async {
    final res = await _supabase
        .from('staff_details')
        .select()
        .eq('id', staffId)
        .maybeSingle();
    return res != null ? StaffDetailModel.fromJson(res) : null;
  }

  /// 3. 計算某員工某月的「預估薪資」 (尚未結算時用)
  Future<PayrollModel> calculateEstimatedSalary({
    required String staffId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1); // 下個月1號

    // A. 抓時薪設定
    final detail = await getStaffDetail(staffId);
    final coachRate = detail?.coachHourlyRate ?? 0;
    final deskRate = detail?.deskHourlyRate ?? 180;

    // B. 抓櫃檯時數 (Work Shifts)
    final shiftsRes = await _supabase
        .from('work_shifts')
        .select()
        .eq('staff_id', staffId)
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());
    final shifts = (shiftsRes as List)
        .map((e) => WorkShiftModel.fromJson(e))
        .toList();
    final totalDeskHours = shifts.fold(0.0, (sum, item) => sum + item.hours);

    // C. 抓教課時數 (Sessions)
    // 這裡假設 sessions 表有關聯 coach_ids (Array)
    final sessionsRes = await _supabase
        .from('sessions')
        .select()
        .contains('coach_ids', [staffId]) // 包含此教練
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());

    // 簡單計算：假設一堂課就是 End - Start
    double totalCoachHours = 0;
    for (var s in sessionsRes) {
      final sTime = DateTime.parse(s['start_time']);
      final eTime = DateTime.parse(s['end_time']);
      totalCoachHours += eTime.difference(sTime).inMinutes / 60.0;
    }

    // D. 計算總額
    final totalAmount =
        (totalCoachHours * coachRate) + (totalDeskHours * deskRate);

    // 回傳一個「假」的 PayrollModel 供前端顯示 (ID 為空代表未存檔)
    return PayrollModel(
      id: '',
      staffId: staffId,
      year: year,
      month: month,
      totalCoachHours: totalCoachHours,
      coachHourlyRate: coachRate,
      totalDeskHours: totalDeskHours,
      deskHourlyRate: deskRate,
      totalAmount: totalAmount.round(),
    );
  }

  /// 4. 儲存/更新薪資單 (結算)
  Future<void> savePayroll(PayrollModel payroll) async {
    // 檢查是否已存在，若有則 Update，若無則 Insert
    // 使用 upsert
    final data = payroll.toJson();
    if (payroll.id.isEmpty) {
      // 如果是預估的假物件，把 id 拿掉讓 DB 自動生成
      data.remove('id');
      data.remove('status'); // 預設 pending
    }

    await _supabase
        .from('payrolls')
        .upsert(data, onConflict: 'staff_id, year, month');
  }
}
