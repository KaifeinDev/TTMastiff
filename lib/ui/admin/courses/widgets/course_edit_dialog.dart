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
        await courseRepository.createCourse(
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

  void _adjustPrice(int amount) {
    // 1. 嘗試將目前文字轉為整數，若為空或格式錯誤則預設為 0
    int currentValue = int.tryParse(_priceController.text) ?? 0;

    // 2. 計算新數值
    int newValue = currentValue + amount;

    // 3. 避免價格變成負數
    if (newValue < 0) newValue = 0;

    // 4. 更新 Controller 顯示
    _priceController.text = newValue.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, c) {
          final maxW = c.maxWidth.clamp(320, 560).toDouble();
          final maxH = c.maxHeight.clamp(520, 720).toDouble();
          return SizedBox(
            width: maxW,
            height: maxH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.course == null ? '新增課程模板' : '編輯課程模板',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: '關閉',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: '課程名稱',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? '請輸入名稱' : null,
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: _category,
                            dropdownColor: Colors.white,
                            decoration: const InputDecoration(
                              labelText: '課程類別',
                              border: OutlineInputBorder(),
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
                            onChanged: _isLoading
                                ? null
                                : (val) => setState(() => _category = val!),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '預設價格',
                              border: const OutlineInputBorder(),
                              prefixText: '\$ ',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.grey,
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () => _adjustPrice(-50),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () => _adjustPrice(50),
                                  ),
                                ],
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? '請輸入價格' : null,
                          ),
                          const SizedBox(height: 16),

                          // 時間欄位：做成跟 TextField 一樣的外觀
                          Row(
                            children: [
                              Expanded(
                                child: _TimeField(
                                  label: '開始時間',
                                  valueText: _startTime.format(context),
                                  onTap: _isLoading
                                      ? null
                                      : () => _pickTime(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TimeField(
                                  label: '結束時間',
                                  valueText: _endTime.format(context),
                                  onTap: _isLoading
                                      ? null
                                      : () => _pickTime(false),
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
                              alignLabelWithHint: true,
                            ),
                            minLines: 2,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(widget.course == null ? '新增' : '更新'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback? onTap;

  const _TimeField({
    required this.label,
    required this.valueText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          valueText.isEmpty ? '請選擇' : valueText,
          style: TextStyle(
            color: valueText.isEmpty ? Colors.grey.shade600 : null,
          ),
        ),
      ),
    );
  }
}
