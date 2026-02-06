import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/student_model.dart';

class StudentSearchDialog extends StatefulWidget {
  final Set<String> existingStudentIds;
  // 移除 allowGuest 參數，不需要了

  const StudentSearchDialog({super.key, required this.existingStudentIds});

  @override
  State<StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<StudentSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<StudentModel> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 可以選擇一進來是否要列出所有 User，或者等使用者輸入
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 單純的搜尋邏輯
      var builder = supabase
          .from('students') // 或是 'users' view
          .select()
          .ilike('name', '%$query%') // 模糊搜尋
          .limit(20);

      final response = await builder;

      final results = (response as List<dynamic>)
          .map((e) => StudentModel.fromJson(e))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      logError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜尋學員 / 散客'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入姓名 (如: 散客)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _search();
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                  ? const Center(child: Text('無搜尋結果'))
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, index) => const Divider(),
                      itemBuilder: (ctx, index) {
                        final student = _searchResults[index];
                        final isAdded = widget.existingStudentIds.contains(
                          student.id,
                        );

                        // 判斷是否為散客 (改為用名字或角色判斷，不依賴 ID)
                        // 這裡只做純顯示的 UI 區分，不做硬性邏輯
                        final isGuestName =
                            student.name.contains('散客') ||
                            student.name.contains('Guest');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isGuestName
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              isGuestName ? Icons.storefront : Icons.person,
                              color: isGuestName
                                  ? Colors.green.shade800
                                  : Colors.blue.shade800,
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: isGuestName
                                ? const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                          subtitle: isGuestName
                              ? const Text('現場收費帳號')
                              : null, // 或顯示餘額
                          trailing: isAdded
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: isAdded
                              ? null
                              : () {
                                  // 回傳真實的資料庫物件
                                  Navigator.pop(context, student);
                                },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
