class StudentModel {
  final String id;
  final String parentId;
  final String name;
  final String? avatarUrl;
  final bool isPrimary; // 🌟 新增：用來判斷是否為「本人」
  // 🌟 level 已由 profiles.membership 取代，這裡僅保留欄位以相容既有資料
  final String level;
  final DateTime birthDate; // 🌟 新增：生日
  final String? gender; // 🌟 新增：性別 ('male', 'female', 'other')
  final String? medicalNote; // 🌟 新增：醫療備註
  final int points; // 🌟 新增：點數

  StudentModel({
    required this.id, 
    required this.parentId, 
    required this.name, 
    this.avatarUrl,
    required this.isPrimary,
    this.level = 'beginner',
    this.gender,
    this.medicalNote,
    required this.birthDate,
    this.points = 0,
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
      gender: json['gender'],
      medicalNote: json['medical_note'],
      points: (json['points'] as int?) ?? 0,
    );
  }
}
