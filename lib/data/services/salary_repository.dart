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

  /// 1. 取得月度薪資報表
  Future<List<Map<String, dynamic>>> getMonthlySalaryReport(
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    final results = await Future.wait([
      _supabase.from('profiles').select(),
      _supabase
          .from('work_shifts')
          .select()
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String()),
      _supabase
          .from('sessions')
          .select()
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String()),
      _supabase.from('payrolls').select().eq('year', year).eq('month', month),
      _supabase.from('staff_details').select(),
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

      // 取得個人設定 (包含該員工的底薪)
      final detail = staffDetails.firstWhere(
        (d) => d.id == staffId,
        orElse: () => StaffDetailModel(
          id: staffId,
          coachHourlyRate: 350, // 預設底薪 (若沒設定)
          deskHourlyRate: 180,
        ),
      );

      final int baseRate = detail.coachHourlyRate; // 🔥 這是關鍵：每個人的底薪不同

      // A. 若已結算
      final saved = savedPayrolls.firstWhere(
        (e) => e.staffId == staffId,
        orElse: () => PayrollModel.empty(),
      );

      if (saved.id.isNotEmpty) {
        report.add({
          'profile': p,
          'payroll': saved,
          'base_rate': baseRate, // 🆕 將底薪傳出去給前端用
          'bank_account': detail.bankAccount,
        });
        continue;
      }

      // B. 未結算 (預覽)
      final myShifts = allShifts.where((s) => s.staffId == staffId).toList();
      final mySessions = allSessions.where((s) {
        final coaches = List<String>.from(s['coach_ids'] ?? []);
        return coaches.contains(staffId);
      }).toList();

      // 🔥 傳入個人的「底薪」進行計算
      final stats = _calculateSalaryStats(
        shifts: myShifts,
        sessions: mySessions,
        deskRate: detail.deskHourlyRate,
        baseCoachRate: baseRate, // 傳入 350 或 500
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
          coachHourlyRate: stats.usedCoachRate,
          deskHourlyRate: detail.deskHourlyRate,
          bonus: 0,
          deduction: 0,
          note: null,
          totalAmount: stats.totalAmount,
          status: 'unsettled',
          adjustmentHours: 0,
        ),
        'bank_account': detail.bankAccount,
        'base_rate': baseRate, // 🆕 將底薪傳出去
      });
    }

    return report;
  }

  /// 2. 儲存薪資單
  Future<void> savePayroll(PayrollModel payroll) async {
    final data = payroll.toJson();
    if (payroll.id.isEmpty) {
      data.remove('id');
    }
    await _supabase
        .from('payrolls')
        .upsert(data, onConflict: 'staff_id, year, month');
  }

  // ==========================================
  // 🔥 私有計算核心 (修正版)
  // ==========================================

  _SalaryStats _calculateSalaryStats({
    required List<WorkShiftModel> shifts,
    required List<dynamic> sessions,
    required int deskRate,
    required int baseCoachRate, // 輸入該員工的底薪
  }) {
    final totalDeskHours = shifts.fold(0.0, (sum, item) => sum + item.hours);

    double totalCoachHours = 0;
    for (var s in sessions) {
      final sTime = DateTime.parse(s['start_time']);
      final eTime = DateTime.parse(s['end_time']);
      totalCoachHours += eTime.difference(sTime).inMinutes / 60.0;
    }

    // 費率判定 (門檻 = 教課 + 櫃檯)
    final double threshold = totalCoachHours + totalDeskHours;

    // 💰 相對增量邏輯：
    // Level 1: Base
    // Level 2: Base + 50
    // Level 3: Base + 100
    int finalRate = baseCoachRate;

    if (threshold > 135) {
      finalRate = baseCoachRate + 100;
    } else if (threshold > 120) {
      finalRate = baseCoachRate + 50;
    }

    final totalAmount =
        (totalCoachHours * finalRate) + (totalDeskHours * deskRate);

    return _SalaryStats(
      totalDeskHours: totalDeskHours,
      totalCoachHours: totalCoachHours,
      totalAmount: totalAmount.round(),
      usedCoachRate: finalRate,
    );
  }

  // ==========================================
  // 輔助功能
  // ==========================================

  Future<StaffDetailModel?> getStaffDetail(String staffId) async {
    final res = await _supabase
        .from('staff_details')
        .select()
        .eq('id', staffId)
        .maybeSingle();
    return res != null ? StaffDetailModel.fromJson(res) : null;
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

  // ✅ 改回你習慣的手動 Map 寫法
  Future<void> updateStaffDetail(StaffDetailModel detail) async {
    final data = {
      'id': detail.id,
      'coach_hourly_rate': detail.coachHourlyRate,
      'desk_hourly_rate': detail.deskHourlyRate,
      'bank_account': detail.bankAccount,
      'status': detail.status, // 如果你的 Model 有這個欄位
      'updated_at': DateTime.now().toIso8601String(),
    };
    // 注意：這裡假設你的 DB 欄位名稱是 snake_case
    await _supabase.from('staff_details').upsert(data);
  }

  Future<void> upsertWorkShift(WorkShiftModel shift) async {
    final data = {
      'staff_id': shift.staffId,
      'start_time': shift.startTime.toIso8601String(),
      'end_time': shift.endTime.toIso8601String(),
      'note': shift.note,
    };
    if (shift.id.isNotEmpty) {
      await _supabase.from('work_shifts').update(data).eq('id', shift.id);
    } else {
      await _supabase.from('work_shifts').insert(data);
    }
  }

  Future<void> deleteWorkShift(String shiftId) async {
    await _supabase.from('work_shifts').delete().eq('id', shiftId);
  }

  /// 單人計算 (例如：點進詳情頁重新整理時可用)
  Future<PayrollModel> calculateEstimatedSalary({
    required String staffId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    // 處理跨年問題
    final end = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    // 1. 抓資料
    final detail = await getStaffDetail(staffId);

    // 🔥 關鍵點：這裡取得的是該員工的「個人底薪」
    final int baseCoachRate = detail?.coachHourlyRate ?? 350;
    final int deskRate = detail?.deskHourlyRate ?? 180;

    // 抓取排班 (Work Shifts)
    final shiftsRes = await _supabase
        .from('work_shifts')
        .select()
        .eq('staff_id', staffId)
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());

    final shifts = (shiftsRes as List)
        .map((e) => WorkShiftModel.fromJson(e))
        .toList();

    // 抓取課程 (Sessions)
    final sessionsRes = await _supabase
        .from('sessions')
        .select()
        .contains('coach_ids', [staffId])
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());

    // 2. 🔥 使用共用計算邏輯 (記得傳入 baseCoachRate)
    final stats = _calculateSalaryStats(
      shifts: shifts,
      sessions: sessionsRes as List,
      deskRate: deskRate,
      baseCoachRate: baseCoachRate, // 傳入個人底薪，讓系統去算是否+50/+100
    );

    // 3. 回傳預覽模型
    return PayrollModel(
      id: '', // 預覽狀態，尚未存檔
      staffId: staffId,
      year: year,
      month: month,
      totalCoachHours: stats.totalCoachHours,
      totalDeskHours: stats.totalDeskHours,

      // 這裡使用的是「算出來的最終費率」(例如 500跳550)
      coachHourlyRate: stats.usedCoachRate,

      deskHourlyRate: deskRate,
      bonus: 0,
      deduction: 0,
      note: null,
      totalAmount: stats.totalAmount,
      status: 'unsettled',
      adjustmentHours: 0, // 系統自動估算時，補正時數預設為 0
    );
  }

  // ==========================================
  // 圖表數據 (Analytics Support)
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

class _SalaryStats {
  final double totalDeskHours;
  final double totalCoachHours;
  final int totalAmount;
  final int usedCoachRate;

  _SalaryStats({
    required this.totalDeskHours,
    required this.totalCoachHours,
    required this.totalAmount,
    required this.usedCoachRate,
  });
}
