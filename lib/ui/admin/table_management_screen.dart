import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/table_model.dart';
import '../../data/services/table_repository.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  late TableRepository _repository;
  List<TableModel> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 假設您已有 Supabase 實體，或從 main.dart 傳入
    _repository = TableRepository(Supabase.instance.client);
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      final tables = await _repository.getTables();
      setState(() {
        _tables = tables;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取失敗: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 處理拖拉排序
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _tables.removeAt(oldIndex);
      _tables.insert(newIndex, item);
    });

    // 呼叫 Repository 更新資料庫順序
    _repository.updateTableOrder(_tables);
  }

  // 顯示新增/編輯對話框
  void _showEditDialog([TableModel? table]) {
    final nameController = TextEditingController(text: table?.name ?? '');
    final capacityController = TextEditingController(
      text: (table?.capacity ?? 2).toString(),
    );
    bool isActive = table?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // 為了讓 Switch 能夠即時更新狀態
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(table == null ? '新增桌次' : '編輯桌次'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '桌次名稱 (如: 第1桌)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(labelText: '建議容納人數'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                if (table != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('啟用狀態'),
                      Switch(
                        value: isActive,
                        onChanged: (val) {
                          setStateDialog(() => isActive = val);
                        },
                      ),
                    ],
                  ),
                  const Text(
                    '若停用，排課時將無法選擇此桌，但不影響歷史紀錄。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final capacity = int.tryParse(capacityController.text) ?? 2;

                  if (name.isEmpty) return;

                  try {
                    if (table == null) {
                      await _repository.createTable(name, capacity);
                    } else {
                      // 更新邏輯
                      final updatedTable = TableModel(
                        id: table.id,
                        name: name,
                        capacity: capacity,
                        isActive: isActive,
                        sortOrder: table.sortOrder,
                      );
                      await _repository.updateTable(updatedTable);
                    }
                    Navigator.pop(context);
                    _loadTables(); // 重新整理
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
                  }
                },
                child: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteTable(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('若此桌次已有排課紀錄，刪除可能會失敗。\n建議改用「編輯」將其設為「停用」。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('仍要刪除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteTable(id);
        _loadTables();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('刪除失敗，請檢查是否已有關聯課程，或改用停用功能。')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('桌次管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTables),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _tables.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final table = _tables[index];
                return Card(
                  key: ValueKey(table.id), // ReorderableListView 需要唯一的 key
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: table.isActive
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      table.name,
                      style: TextStyle(
                        decoration: table.isActive
                            ? null
                            : TextDecoration.lineThrough,
                        color: table.isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      '容納: ${table.capacity} 人 ${table.isActive ? "" : "(已停用)"}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditDialog(table),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteTable(table.id),
                        ),
                        const Icon(
                          Icons.drag_handle,
                          color: Colors.grey,
                        ), // 拖拉提示圖示
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新增桌次'),
      ),
    );
  }
}
