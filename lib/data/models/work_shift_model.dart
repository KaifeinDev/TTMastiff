class WorkShiftModel {
  final String id;
  final String staffId;
  final DateTime startTime;
  final DateTime endTime;
  final String? note;

  WorkShiftModel({
    required this.id,
    required this.staffId,
    required this.startTime,
    required this.endTime,
    this.note,
  });

  // 計算時數 (小數點後2位)
  double get hours => endTime.difference(startTime).inMinutes / 60.0;

  factory WorkShiftModel.fromJson(Map<String, dynamic> json) {
    return WorkShiftModel(
      id: json['id'],
      staffId: json['staff_id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      note: json['note'],
    );
  }
}
