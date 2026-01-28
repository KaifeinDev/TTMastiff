import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/activity_model.dart';
import 'dashed_card.dart';

class ActivityEditDialog extends StatefulWidget {
  final String titleText;
  final ActivityModel? initial;
  final String fixedType; // 'carousel' | 'recent'
  final bool allowTypeChange;

  final Future<void> Function({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String? base64Image,
    required String type,
  }) onSubmit;

  const ActivityEditDialog({
    super.key,
    required this.titleText,
    required this.fixedType,
    required this.onSubmit,
    this.initial,
    this.allowTypeChange = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String titleText,
    required String fixedType,
    required Future<void> Function({
      required String title,
      required String description,
      required DateTime startTime,
      required DateTime endTime,
      required String? base64Image,
      required String type,
    }) onSubmit,
    ActivityModel? initial,
    bool allowTypeChange = false,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ActivityEditDialog(
        titleText: titleText,
        fixedType: fixedType,
        onSubmit: onSubmit,
        initial: initial,
        allowTypeChange: allowTypeChange,
      ),
    );
  }

  @override
  State<ActivityEditDialog> createState() => _ActivityEditDialogState();
}

class _ActivityEditDialogState extends State<ActivityEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _startTime;
  DateTime? _endTime;
  String? _base64Image;
  Uint8List? _imageBytes; // preview
  bool _submitting = false;
  late String _type;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _type = widget.fixedType;
    if (init != null) {
      _titleController.text = init.title;
      _descriptionController.text = init.description;
      _startTime = init.startTime;
      _endTime = init.endTime;
      _base64Image = init.image;
      if (_base64Image != null && _base64Image!.isNotEmpty) {
        try {
          _imageBytes = base64Decode(_base64Image!);
        } catch (_) {}
      }
    } else {
      _startTime = null;
      _endTime = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _startTime : _endTime;
    final initialDate = current ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = dt;
        // 若 end 早於 start，先自動清掉避免送出錯
        if (_endTime != null && _endTime!.isBefore(dt)) {
          _endTime = null;
        }
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    Uint8List bytes;
    if (kIsWeb) {
      bytes = await picked.readAsBytes();
    } else {
      final file = File(picked.path);
      bytes = await file.readAsBytes();
    }

    setState(() {
      _imageBytes = bytes;
      _base64Image = base64Encode(bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

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
                          widget.titleText,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _submitting
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
                              labelText: '標題',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                          ),
                          const SizedBox(height: 16),

                          // 時間欄位：做成跟 TextField 一樣的外觀
                          Row(
                            children: [
                              Expanded(
                                child: _TimeField(
                                  label: '開始時間',
                                  valueText: _startTime == null
                                      ? ''
                                      : dateFormat.format(_startTime!),
                                  onTap: _submitting
                                      ? null
                                      : () => _pickDateTime(isStart: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TimeField(
                                  label: '結束時間',
                                  valueText: _endTime == null
                                      ? ''
                                      : dateFormat.format(_endTime!),
                                  onTap: _submitting
                                      ? null
                                      : () => _pickDateTime(isStart: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 附件區塊：像你截圖那樣（雲 icon，圖片縮圖在框內）
                          _AttachmentBox(
                            bytes: _imageBytes,
                            onPick: _submitting ? null : _pickImage,
                          ),
                          const SizedBox(height: 16),

                          // description：固定寬度內自動換行，不撐對話框
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: '描述',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            minLines: 4,
                            maxLines: 6,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '請輸入描述'
                                : null,
                          ),

                          if (widget.allowTypeChange) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _type,
                              decoration: const InputDecoration(
                                labelText: '區塊',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'carousel',
                                  child: Text('輪播'),
                                ),
                                DropdownMenuItem(
                                  value: 'recent',
                                  child: Text('近期活動'),
                                ),
                              ],
                              onChanged: _submitting
                                  ? null
                                  : (v) => setState(() => _type = v ?? _type),
                            ),
                          ],
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
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  if (_startTime == null || _endTime == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('請選擇開始與結束時間'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (_endTime!.isBefore(_startTime!)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('結束時間不能早於開始時間'),
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _submitting = true);
                                  try {
                                    await widget.onSubmit(
                                      title: _titleController.text.trim(),
                                      description:
                                          _descriptionController.text.trim(),
                                      startTime: _startTime!,
                                      endTime: _endTime!,
                                      base64Image: _base64Image?.isEmpty == true
                                          ? null
                                          : _base64Image,
                                      type: _type,
                                    );
                                    if (mounted) Navigator.of(context).pop();
                                  } catch (e, stackTrace) {
                                    if (!mounted) return;
                                    debugPrint('ActivityEditDialog submit error: $e');
                                    debugPrint('Stack trace: $stackTrace');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('儲存失敗: ${e.toString()}'),
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                    setState(() => _submitting = false);
                                  }
                                },
                          child: Text(widget.initial == null ? '新增' : '更新'),
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
          suffixIcon: const Icon(Icons.calendar_month),
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

class _AttachmentBox extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback? onPick;

  const _AttachmentBox({required this.bytes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return DashedCard(
      radius: 12,
      borderColor: Colors.grey.shade400,
      padding: const EdgeInsets.all(12),
      onTap: onPick,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '附件（可上傳 .jpg/.png）',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                if (bytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      bytes!,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                else
                  Text(
                    '點擊右上角雲朵上傳圖片',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onPick,
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: '上傳圖片',
          ),
        ],
      ),
    );
  }
}

