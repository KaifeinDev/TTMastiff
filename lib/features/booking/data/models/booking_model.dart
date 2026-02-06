import '../../../course/data/models/session_model.dart';
import '../../../student/data/models/student_model.dart';

class BookingModel {
  final String id;
  final String status; // 'confirmed', 'cancelled'
  final String attendanceStatus; // 'pending', 'attended', 'absent' (對應 SQL)
  final int priceSnapshot; // 對應 SQL
  final String studentId;
  final String sessionId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? guestName;
  final String? guestPhone;

  // 關聯物件
  final SessionModel session;
  final StudentModel? student;

  BookingModel({
    required this.id,
    required this.status,
    required this.attendanceStatus,
    required this.priceSnapshot,
    required this.studentId,
    required this.sessionId,
    required this.createdAt,
    this.updatedAt,
    required this.session,
    this.student,
    this.guestName,
    this.guestPhone,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'],
      status: json['status'] ?? 'confirmed',
      // 讀取 DB 中的 attendance_status，若無則預設 pending
      attendanceStatus: json['attendance_status'] ?? 'pending',
      // 讀取價格快照，若 null 則補 0
      priceSnapshot: json['price_snapshot'] ?? 0,
      studentId: json['student_id'],
      sessionId: json['session_id'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at']).toLocal()
          : null,
      guestName: json['guest_name'],
      guestPhone: json['guest_phone'],

      // 處理關聯資料
      session: SessionModel.fromJson(json['sessions']),
      student: json['students'] != null
          ? StudentModel.fromJson(json['students'])
          : null,
    );
  }

  // 🔥 Helper Getters (讓 UI 寫法更簡潔)
  DateTime get endTime => session.endTime;
  DateTime get startTime => session.startTime;
  String get courseTitle => session.courseTitle;
}
