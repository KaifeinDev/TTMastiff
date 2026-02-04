import 'package:flutter/material.dart';
import 'package:ttmastiff/main.dart'; // 確保能存取 adminRepository
import '../../../../data/models/course_model.dart';

class CourseEditDialog extends StatefulWidget {
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
      _titleController.text = c.title;
      _descController.text = c.description ?? '';
      _priceController.text = c.price.toString();
      _category = c.category;
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
      final now = DateTime.now();

      // 如果是 rental，時間不重要，給預設值以符合 DB schema
      // 如果是課程，使用選定的時間
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

      final int price = int.tryParse(_priceController.text) ?? 0;

      if (widget.course == null) {
        await courseRepository.createCourse(
          title: _titleController.text,
          category: _category,
          price: price,
          description: _descController.text,
          defaultStartTime: dtStart,
          defaultEndTime: dtEnd,
        );
      } else {
        await courseRepository.updateCourse(
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
    void _adjustPrice(int amount) {
      int currentValue = int.tryParse(_priceController.text) ?? 0;
      int newValue = currentValue + amount;
      if (newValue < 0) newValue = 0;
      _priceController.text = newValue.toString();
    }

    // 判斷是否為租桌
    final bool isRental = _category == 'rental';

    return AlertDialog(
      title: Text(widget.course == null ? '新增項目模板' : '編輯項目模板'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 名稱
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '名稱 (Title)',
                    hintText: '例如：基礎桌球課 / 一般租桌',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? '請輸入名稱' : null,
                ),
                const SizedBox(height: 16),

                // 2. 類別選擇
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: '類別 (Category)',
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
                    DropdownMenuItem(
                      value: 'rental',
                      child: Text('租桌 (Rental)'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _category = val!),
                ),
                const SizedBox(height: 16),

                // 3. 價格 (標籤動態變化)
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isRental ? '每小時費率 (Hourly Rate)' : '課程單堂價格',
                    border: const OutlineInputBorder(),
                    prefixText: '\$ ',
                    filled: true,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.grey,
                          ),
                          onPressed: () => _adjustPrice(-50),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.blue,
                          ),
                          onPressed: () => _adjustPrice(50),
                        ),
                      ],
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? '請輸入價格' : null,
                ),
                const SizedBox(height: 16),

                // 4. 時間選擇 (僅在非租桌時顯示)
                // 租桌的時間是隨機的，因此不需要設定「預設時間」
                if (!isRental) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          onPressed: () => _pickTime(true),
                          label: Text('預設開始: ${_startTime.format(context)}'),
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
                          label: Text('預設結束: ${_endTime.format(context)}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // 顯示提示訊息代替時間選擇器
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      '💡 租桌類型的時間長度將於建立預約時動態決定，無需設定預設時間。',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. 描述
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
