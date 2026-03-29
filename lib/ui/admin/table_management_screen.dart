import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/main.dart';
import '../../data/models/table_model.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  List<TableModel> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      final tables = await tableRepository.getTables();
      tables.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() {
        _tables = tables;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e, prefix: '讀取失敗：');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleTableStatus(TableModel table, bool newStatus) async {
    // 為了 UX 體驗，先在 UI 上更新狀態 (Optimistic UI)，失敗再改回來，或者直接重整
    // 這裡採用直接呼叫 API 後重整的方式確保資料一致性
    if (!table.isActive) {
      await _updateStatus(table, true);
      return;
    }

    try {
      final usageCount = await tableRepository.checkTableUsage(table.id);

      if (mounted) {
        setState(() => _isLoading = false); // 關閉讀取圈圈以便顯示 Dialog

        if (usageCount > 0) {
          // 情況：有衝突，顯示嚴重警告
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ 警告：桌次使用中'),
              content: Text(
                '「${table.name}」目前被排定在 $usageCount 堂未來的課程中。\n\n'
                '強制停用可能會導致這些課程的座位安排出現混亂。\n'
                '建議先調整排課，或確認現場已有替代方案。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('強制停用'),
                ),
              ],
            ),
          );

          if (confirm != true) return; // 使用者後悔了
        } // 沒衝突就直接關
        await _updateStatus(table, false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, e, prefix: '狀態更新失敗：');
      }
    }
  }

  Future<void> _updateStatus(TableModel table, bool isActive) async {
    try {
      // 建立新的物件 (假設您的 Model 有 copyWith，或是手動建)
      final newTable = TableModel(
        id: table.id,
        name: table.name,
        capacity: table.capacity,
        isActive: isActive, // 更新這裡
        sortOrder: table.sortOrder,
        remarks: table.remarks,
      );

      await tableRepository.updateTable(newTable);
      await _loadTables(); // 重整列表

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(isActive ? '已啟用桌次' : '已停用桌次')));
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e, prefix: '更新失敗：');
      }
    }
  }

  // 顯示新增/編輯對話框
  void _showEditDialog([TableModel? table]) {
    final nameController = TextEditingController(text: table?.name ?? '');
    final capacityController = TextEditingController(
      text: (table?.capacity ?? 2).toString(),
    );
    final remarksController = TextEditingController(text: table?.remarks ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            // 🔥 新增：備註輸入框
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: '備註 (選填)',
                hintText: '例如：靠窗、有柱子...',
              ),
            ),
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
              final remarks = remarksController.text.trim();

              if (name.isEmpty) return;

              try {
                if (table == null) {
                  // 新增時，預設啟用
                  // 注意：createTable 方法可能需要更新以接收 remarks
                  await tableRepository.createTable(
                    name,
                    capacity,
                    remarks: remarks,
                  );
                } else {
                  // 更新邏輯
                  final updatedTable = TableModel(
                    id: table.id,
                    name: name,
                    capacity: capacity,
                    isActive: table.isActive, // 保持原本狀態
                    sortOrder: table.sortOrder,
                    remarks: remarks, // 🔥 更新備註
                  );
                  await tableRepository.updateTable(updatedTable);
                }
                if (mounted) {
                  Navigator.pop(context);
                  _loadTables();
                }
              } catch (e) {
                if (mounted) {
                  showErrorSnackBar(context, e, prefix: '儲存失敗：');
                }
              }
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  /*
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
        await tableRepository.deleteTable(id);
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
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('桌次管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTables),
        ],
      ),
      // 🔥 修改 1: 改用 ListView (移除 ReorderableListView)
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final table = _tables[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8, // 稍微加大間距
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: table.isActive
                          ? Colors.transparent
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // 左側：桌號圓圈
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: table.isActive
                              ? Colors.blue.shade100
                              : Colors.grey.shade200,
                          child: Text(
                            table.name.replaceAll(
                              RegExp(r'\D'),
                              '',
                            ), // 嘗試只顯示數字，或直接用 index+1
                            style: TextStyle(
                              color: table.isActive
                                  ? Colors.blue.shade900
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 中間：資訊區 (名稱、容納人數、備註)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: table.isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                  color: table.isActive
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '容納: ${table.capacity} 人',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              // 🔥 修改 2: 顯示備註
                              if (table.remarks != null &&
                                  table.remarks!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '註: ${table.remarks}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 右側：操作區 (Switch + 編輯按鈕)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🔥 修改 4: 把狀態切換移到這裡
                            Column(
                              children: [
                                Switch(
                                  value: table.isActive,
                                  activeColor: Colors.green,
                                  onChanged: (val) =>
                                      _toggleTableStatus(table, val),
                                ),
                                Text(
                                  table.isActive ? "啟用中" : "已停用",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: table.isActive
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditDialog(table),
                            ),
                            // 🔥 修改 3: 刪除按鈕已註解
                            /*
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteTable(table.id),
                            ),
                            */
                          ],
                        ),
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
