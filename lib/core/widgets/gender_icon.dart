import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import '../../../core/constants/gender_types.dart';

/// 性別圖示 Widget
class GenderIcon extends StatelessWidget {
  final String? gender;

  const GenderIcon({super.key, this.gender});

  @override
  Widget build(BuildContext context) {
    if (gender == null) return const SizedBox.shrink();

    switch (gender) {
      case GenderTypes.male:
        return const Icon(Icons.male, color: Colors.blueAccent);
      case GenderTypes.female:
        return const Icon(Icons.female, color: Colors.redAccent);
      case GenderTypes.other:
        return Icon(Icons.transgender, color: Colors.grey.shade600);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Helper 函數：根據性別返回對應的 icon（向後兼容）
Widget buildGenderIcon(String? gender) {
  return GenderIcon(gender: gender);
}
