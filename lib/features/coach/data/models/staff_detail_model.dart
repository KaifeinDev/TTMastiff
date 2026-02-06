class StaffDetailModel {
  final String id;
  final int coachHourlyRate;
  final int deskHourlyRate;
  final String? bankAccount;
  final String status;

  StaffDetailModel({
    required this.id,
    this.coachHourlyRate = 0,
    this.deskHourlyRate = 180,
    this.bankAccount,
    this.status = 'active',
  });

  factory StaffDetailModel.fromJson(Map<String, dynamic> json) {
    return StaffDetailModel(
      id: json['id'],
      coachHourlyRate: json['coach_hourly_rate'] ?? 0,
      deskHourlyRate: json['desk_hourly_rate'] ?? 180,
      bankAccount: json['bank_account'],
      status: json['status'] ?? 'active',
    );
  }
}
