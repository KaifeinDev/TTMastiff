import 'package:flutter/material.dart';
import 'package:ttmastiff/main.dart'; // 確保能存取 adminRepository

// 🔥 引入 Model
import '../../../../data/models/course_model.dart';

class CourseEditDialog extends StatefulWidget {
  // 🔥 改動 1: 這裡接收 Model，如果是 null 代表新增
  final CourseModel? course;

  const CourseEditDialog({super.key, this.course});

  @override
  State<CourseEditDialog> createState() => _CourseEditDialogState();
}

class _CourseEditDialogState extends State<CourseEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  String _category = 'group';
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      final c = widget.course!;
      // 🔥 改動 2: 使用點語法存取屬性，有型別提示
      _titleController.text = c.title;
      _descController.text = c.description ?? '';
      _priceController.text = c.price.toString();
      _category = c.category;

      // 🔥 改動 3: Model 內的 startTime 已經是 DateTime，直接轉 TimeOfDay
      // 不需要 DateTime.parse()
      _startTime = TimeOfDay.fromDateTime(c.defaultStartTime);
      _endTime = TimeOfDay.fromDateTime(c.defaultEndTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 為了存入 DB，我們需要一個基準日期 (Date) 加上 時間 (Time)
      // 這裡統一使用今天的日期，因為 Course 的 start_time 主要是看它的 "TimeOfDay"
      final now = DateTime.now();
      final dtStart = DateTime(
        now.year,
        now.month,
        now.day,
        _startTime.hour,
        _startTime.minute,
      );
      final dtEnd = DateTime(
        now.year,
        now.month,
        now.day,
        _endTime.hour,
        _endTime.minute,
      );

      // 防呆轉型
      final int price = int.tryParse(_priceController.text) ?? 0;

      if (widget.course == null) {
        // Create
        await adminRepository.createCourse(
          title: _titleController.text,
          category: _category,
          price: price,
          description: _descController.text,
          defaultStartTime: dtStart,
          defaultEndTime: dtEnd,
        );
      } else {
        // Update
        // 🔥 改動 4: 使用 widget.course!.id 取得 ID
        await adminRepository.updateCourse(
          courseId: widget.course!.id,
          title: _titleController.text,
          category: _category,
          price: price,
          description: _descController.text,
          defaultStartTime: dtStart,
          defaultEndTime: dtEnd,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.course == null ? '新增課程模板' : '編輯課程模板'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '課程名稱',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? '請輸入名稱' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: '課程類別',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'group',
                      child: Text('團體課 (Group)'),
                    ),
                    DropdownMenuItem(
                      value: 'personal',
                      child: Text('個人課 (Personal)'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _category = val!),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '預設價格',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? '請輸入價格' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        onPressed: () => _pickTime(true),
                        label: Text('開始: ${_startTime.format(context)}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_filled),
                        onPressed: () => _pickTime(false),
                        label: Text('結束: ${_endTime.format(context)}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: '描述 (選填)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('儲存'),
        ),
      ],
    );
  }
}
