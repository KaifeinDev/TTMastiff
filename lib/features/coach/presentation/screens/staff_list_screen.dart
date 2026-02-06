import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'staff_detail_screen.dart'; // 引用您剛剛做的詳情頁

class StaffListScreen extends StatelessWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('人員管理')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // 直接撈取 profiles
        future: Supabase.instance.client
            .from('profiles')
            .select()
            .then((data) => List<Map<String, dynamic>>.from(data)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('錯誤: ${snapshot.error}'));
          }
          final staffList = snapshot.data ?? [];

          return ListView.builder(
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(staff['full_name'] ?? '未命名'),
                  subtitle: const Text('點擊管理排班與薪資設定'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 🔥 點擊後跳轉到您剛剛做的 StaffDetailScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffDetailScreen(profile: staff),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}