class StudentModel {
  final String id;
  final String parentId;
  final String name;
  final String? avatarUrl;
  final bool isPrimary; // 🌟 新增：用來判斷是否為「本人」
  final String level;   // 🌟 新增：程度 (對應 DB V3)
  final DateTime birthDate; // 🌟 新增：生日
  final String? medical_note; // 🌟 新增：醫療備註

  StudentModel({
    required this.id, 
    required this.parentId, 
    required this.name, 
    this.avatarUrl,
    required this.isPrimary,
    this.level = 'beginner',
    this.medical_note,
    required this.birthDate,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      // 資料庫欄位是 is_primary，若為 null 預設 false
      isPrimary: json['is_primary'] ?? false, 
      level: json['level'] ?? 'beginner',
      birthDate: DateTime.parse(json['birth_date'] as String), 
      medical_note: json['medical_note'],
    );
  }
}
