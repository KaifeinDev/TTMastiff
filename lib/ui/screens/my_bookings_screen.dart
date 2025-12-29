import 'package:flutter/material.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的課程')),
      body: const Center(child: Text('這裡顯示已報名的課程 (待實作)')),
    );
  }
}
