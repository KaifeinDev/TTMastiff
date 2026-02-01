import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../data/models/student_model.dart';

class StudentSearchDialog extends StatefulWidget {
  // 傳入已經選過的 ID，避免重複選取
  final Set<String> existingStudentIds;

  const StudentSearchDialog({super.key, required this.existingStudentIds});

  @override
  State<StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<StudentSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<StudentModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 搜尋邏輯 (參考 session_edit_dialog)
  Future<void> _search() async {
    final query = _searchController.text.trim();
    // if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final response = await Supabase.instance.client
          .from('students')
          .select()
          .ilike('name', '%$query%') // 模糊搜尋
          .limit(20); // 限制筆數避免太多

      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _searchResults = data.map((e) => StudentModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('搜尋失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜尋並加入學員'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // 搜尋框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入姓名...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),

            // 搜尋結果列表
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        '請輸入關鍵字搜尋',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = _searchResults[index];
                        // 檢查是否已經在「已選清單」中
                        final isAdded = widget.existingStudentIds.contains(
                          student.id,
                        );

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAdded
                                ? Colors.grey
                                : Colors.grey.shade200,
                            child: Text(student.name.substring(0, 1)),
                          ),
                          title: Text(student.name),
                          subtitle: isAdded
                              ? const Text(
                                  '已加入列表',
                                  style: TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: isAdded
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(Icons.add_circle_outline),
                          onTap: isAdded
                              ? null // 已加入就不能點
                              : () {
                                  // 點擊後直接回傳該學生
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
