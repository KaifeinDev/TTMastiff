import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payroll_model.dart';
import '../models/work_shift_model.dart';
import '../models/staff_detail_model.dart';

class SalaryRepository {
  final SupabaseClient _supabase;
  SalaryRepository(this._supabase);

  // ==========================================
  // 核心功能區
  // ==========================================

  /// 1. 取得月度薪資報表 (高效能 Batch Fetching)
  Future<List<Map<String, dynamic>>> getMonthlySalaryReport(
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    // 平行請求：5 次 DB 查詢解決所有問題
    final results = await Future.wait([
      _supabase.from('profiles').select(), // 0
      _supabase
          .from('work_shifts')
          .select()
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String()), // 1
      _supabase
          .from('sessions')
          .select()
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String()), // 2
      _supabase
          .from('payrolls')
          .select()
          .eq('year', year)
          .eq('month', month), // 3
      _supabase.from('staff_details').select(), // 4
    ]);

    final profiles = results[0] as List;
    final allShifts = (results[1] as List)
        .map((e) => WorkShiftModel.fromJson(e))
        .toList();
    final allSessions = results[2] as List;
    final savedPayrolls = (results[3] as List)
        .map((e) => PayrollModel.fromJson(e))
        .toList();
    final staffDetails = (results[4] as List)
        .map((e) => StaffDetailModel.fromJson(e))
        .toList();

    List<Map<String, dynamic>> report = [];

    for (var p in profiles) {
      final staffId = p['id'];

      // A. 檢查是否已存檔
      final saved = savedPayrolls.firstWhere(
        (e) => e.staffId == staffId,
        orElse: () => PayrollModel.empty(),
      );

      if (saved.id.isNotEmpty) {
        report.add({'profile': p, 'payroll': saved});
        continue;
      }

      // B. 未存檔，執行即時計算
      // 過濾出此人的資料
      final myShifts = allShifts.where((s) => s.staffId == staffId).toList();
      final mySessions = allSessions.where((s) {
        final coaches = List<String>.from(s['coach_ids'] ?? []);
        return coaches.contains(staffId);
      }).toList();

      // 取得費率
      final detail = staffDetails.firstWhere(
        (d) => d.id == staffId,
        orElse: () => StaffDetailModel(
          id: staffId,
          coachHourlyRate: 0,
          deskHourlyRate: 180,
        ),
      );

      // 🔥 使用共用計算邏輯
      final stats = _calculateSalaryStats(
        shifts: myShifts,
        sessions: mySessions,
        coachRate: detail.coachHourlyRate,
        deskRate: detail.deskHourlyRate,
      );

      report.add({
        'profile': p,
        'payroll': PayrollModel(
          id: '',
          staffId: staffId,
          year: year,
          month: month,
          totalCoachHours: stats.totalCoachHours,
          totalDeskHours: stats.totalDeskHours,
          coachHourlyRate: detail.coachHourlyRate,
          deskHourlyRate: detail.deskHourlyRate,
          bonus: 0,
          deduction: 0,
          note: null,
          totalAmount: stats.totalAmount,
          status: 'pending',
        ),
      });
    }

    return report;
  }

  /// 2. 儲存/更新薪資單
  Future<void> savePayroll(PayrollModel payroll) async {
    final data = payroll.toJson();
    if (payroll.id.isEmpty) {
      data.remove('id');
      // 如果這邊不 remove status，就會把 'pending' 寫進去，這也是對的
      // 但通常讓資料庫 default 值處理會比較乾淨
      if (data['status'] == 'pending') {
        data.remove('status');
      }
    }
    await _supabase
        .from('payrolls')
        .upsert(data, onConflict: 'staff_id, year, month');
  }

  // ==========================================
  // 輔助方法 (舊有的單人查詢功能，保留備用)
  // ==========================================

  Future<StaffDetailModel?> getStaffDetail(String staffId) async {
    final res = await _supabase
        .from('staff_details')
        .select()
        .eq('id', staffId)
        .maybeSingle();
    return res != null ? StaffDetailModel.fromJson(res) : null;
  }

  /// 單人計算 (例如：點進詳情頁重新整理時可用)
  Future<PayrollModel> calculateEstimatedSalary({
    required String staffId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    // 1. 抓資料
    final detail = await getStaffDetail(staffId);
    final coachRate = detail?.coachHourlyRate ?? 0;
    final deskRate = detail?.deskHourlyRate ?? 180;

    final shiftsRes = await _supabase
        .from('work_shifts')
        .select()
        .eq('staff_id', staffId)
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());
    final shifts = (shiftsRes as List)
        .map((e) => WorkShiftModel.fromJson(e))
        .toList();

    final sessionsRes = await _supabase
        .from('sessions')
        .select()
        .contains('coach_ids', [staffId])
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());

    // 2. 🔥 使用共用計算邏輯
    final stats = _calculateSalaryStats(
      shifts: shifts,
      sessions: sessionsRes as List,
      coachRate: coachRate,
      deskRate: deskRate,
    );

    return PayrollModel(
      id: '',
      staffId: staffId,
      year: year,
      month: month,
      totalCoachHours: stats.totalCoachHours,
      coachHourlyRate: coachRate,
      totalDeskHours: stats.totalDeskHours,
      deskHourlyRate: deskRate,
      totalAmount: stats.totalAmount,
    );
  }

  // ==========================================
  // 🔥 私有計算核心 (避免邏輯重複)
  // ==========================================

  _SalaryStats _calculateSalaryStats({
    required List<WorkShiftModel> shifts,
    required List<dynamic> sessions,
    required int coachRate,
    required int deskRate,
  }) {
    // 1. 櫃檯時數
    final totalDeskHours = shifts.fold(0.0, (sum, item) => sum + item.hours);

    // 2. 教課時數
    double totalCoachHours = 0;
    for (var s in sessions) {
      final sTime = DateTime.parse(s['start_time']);
      final eTime = DateTime.parse(s['end_time']);
      totalCoachHours += eTime.difference(sTime).inMinutes / 60.0;
    }

    // 3. 總額
    final totalAmount =
        (totalCoachHours * coachRate) + (totalDeskHours * deskRate);

    return _SalaryStats(
      totalDeskHours: totalDeskHours,
      totalCoachHours: totalCoachHours,
      totalAmount: totalAmount.round(),
    );
  }

  // ==========================================
  // 新增功能：員工詳情與排班管理 (Staff Detail Support)
  // ==========================================

  /// 更新員工基本設定 (時薪、銀行帳號)
  Future<void> updateStaffDetail(StaffDetailModel detail) async {
    final data = {
      'id': detail.id,
      'coach_hourly_rate': detail.coachHourlyRate,
      'desk_hourly_rate': detail.deskHourlyRate,
      'bank_account': detail.bankAccount,
      'status': detail.status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _supabase.from('staff_details').upsert(data);
  }

  /// 取得某員工特定月份的所有排班
  Future<List<WorkShiftModel>> getStaffShifts(
    String staffId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final res = await _supabase
        .from('work_shifts')
        .select()
        .eq('staff_id', staffId)
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String())
        .order('start_time');

    return (res as List).map((e) => WorkShiftModel.fromJson(e)).toList();
  }

  /// 新增或更新排班
  Future<void> upsertWorkShift(WorkShiftModel shift) async {
    final data = {
      'staff_id': shift.staffId,
      'start_time': shift.startTime.toIso8601String(),
      'end_time': shift.endTime.toIso8601String(),
      'note': shift.note,
    };
    if (shift.id.isNotEmpty) {
      data['id'] = shift.id;
    } else {
      // 如果是新增，確保不傳空ID，讓 DB 自動生成
    }

    // 如果 id 是空的，Supabase 不一定會自動忽略，建議分開寫或不傳 id
    if (shift.id.isEmpty) {
      await _supabase.from('work_shifts').insert(data);
    } else {
      await _supabase.from('work_shifts').update(data).eq('id', shift.id);
    }
  }

  /// 刪除排班
  Future<void> deleteWorkShift(String shiftId) async {
    await _supabase.from('work_shifts').delete().eq('id', shiftId);
  }

  // ==========================================
  // 新增功能：圖表數據 (Analytics Support)
  // ==========================================

  /// 取得某一年份的所有已結算薪資單 (用於圖表)
  Future<List<PayrollModel>> getYearlyPayrolls(int year) async {
    final res = await _supabase
        .from('payrolls')
        .select()
        .eq('year', year)
        .order('month');
    return (res as List).map((e) => PayrollModel.fromJson(e)).toList();
  }
}

// 用一個簡單的小 class 來傳遞計算結果
class _SalaryStats {
  final double totalDeskHours;
  final double totalCoachHours;
  final int totalAmount;

  _SalaryStats({
    required this.totalDeskHours,
    required this.totalCoachHours,
    required this.totalAmount,
  });
}
