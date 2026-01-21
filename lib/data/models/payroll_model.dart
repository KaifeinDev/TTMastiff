class PayrollModel {
  final String id;
  final String staffId;
  final int year;
  final int month;
  final double totalCoachHours;
  final int coachHourlyRate;
  final double totalDeskHours;
  final int deskHourlyRate;
  final int bonus;
  final int deduction;
  final String? note;
  final int totalAmount;
  final String status;
  final double? adjustmentHours;

  PayrollModel({
    required this.id,
    required this.staffId,
    required this.year,
    required this.month,
    required this.totalCoachHours,
    required this.coachHourlyRate,
    required this.totalDeskHours,
    required this.deskHourlyRate,
    this.bonus = 0,
    this.deduction = 0,
    this.note,
    required this.totalAmount,
    this.status = 'pending',
    this.adjustmentHours = 0,
  });

  factory PayrollModel.empty() {
    return PayrollModel(
      id: '', // ID 為空，代表尚未寫入資料庫 (Unsaved)
      staffId: '',
      year: 0,
      month: 0,
      totalCoachHours: 0.0,
      coachHourlyRate: 0,
      totalDeskHours: 0.0,
      deskHourlyRate: 0,
      bonus: 0,
      deduction: 0,
      note: null,
      totalAmount: 0,
      status: 'pending',
      adjustmentHours: 0,
    );
  }

  factory PayrollModel.fromJson(Map<String, dynamic> json) {
    return PayrollModel(
      id: json['id'],
      staffId: json['staff_id'],
      year: json['year'],
      month: json['month'],
      totalCoachHours: (json['total_coach_hours'] ?? 0).toDouble(),
      coachHourlyRate: json['coach_hourly_rate'] ?? 0,
      totalDeskHours: (json['total_desk_hours'] ?? 0).toDouble(),
      deskHourlyRate: json['desk_hourly_rate'] ?? 0,
      bonus: json['bonus'] ?? 0,
      deduction: json['deduction'] ?? 0,
      note: json['note'],
      totalAmount: json['total_amount'] ?? 0,
      status: json['status'] ?? 'pending',
      adjustmentHours: json['adjustment_hours'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'year': year,
      'month': month,
      'total_coach_hours': totalCoachHours,
      'coach_hourly_rate': coachHourlyRate,
      'total_desk_hours': totalDeskHours,
      'desk_hourly_rate': deskHourlyRate,
      'bonus': bonus,
      'deduction': deduction,
      'note': note,
      'total_amount': totalAmount,
      'status': status,
      'adjustment_hours': adjustmentHours,
    };
  }
}
