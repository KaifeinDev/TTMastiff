import 'package:flutter/material.dart';

/// Helper 函數：根據性別返回對應的 icon
Widget buildGenderIcon(String? gender) {
  if (gender == null) return const SizedBox.shrink();
  
  switch (gender) {
    case 'male':
      return const Icon(Icons.male, color: Colors.blueGrey);
    case 'female':
      return const Icon(Icons.female, color: Colors.redAccent);
    case 'other':
      return Icon(Icons.transgender, color: Colors.grey.shade600);
    default:
      return const SizedBox.shrink();
  }
}
