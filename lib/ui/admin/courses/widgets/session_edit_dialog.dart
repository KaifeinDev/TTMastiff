import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart'; // adminRepository

// 🔥 引入 Model
import '../../../../data/models/session_model.dart';

class SessionEditDialog extends StatefulWidget {
  // 🔥 改動 1: 這裡接收 Model
  final SessionModel session;
  final String category; // 用來輔助計算人數上限

  const SessionEditDialog({
    super.key,
    required this.session,
    required this.category,
  });

  @override
  State<SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends State<SessionEditDialog> {
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();

  List<Map<String, dynamic>> _allCoaches = [];
  List<String> _selectedCoachIds = [];

  late DateTime _startDateTime;
  late DateTime _endDateTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCoaches();

    // 🔥 改動 2: 使用 Model 初始化
    final s = widget.session;
    _locationController.text = s.location ?? '';
    _capacityController.text = s.maxCapacity.toString();
    // 這裡我們建立一個新的 List，避免改動原資料
    _selectedCoachIds = List<String>.from(s.coachIds);

    // Model 的時間已經是 DateTime，不需 parse
    _startDateTime = s.startTime;
    _endDateTime = s.endTime;
  }

  @override
  void dispose() {
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoaches() async {
    try {
      final coaches = await adminRepository.getCoaches();
      if (mounted) {
        setState(() => _allCoaches = coaches);
      }
    } catch (e) {
      debugPrint('Fetch coaches error: $e');
    }
  }

  // 自動計算人數 (同 batch 邏輯)
  void _recalcCapacity() {
    if (widget.category == 'personal') return; // 個人課不自動改
    int count = _selectedCoachIds.isEmpty ? 1 : _selectedCoachIds.length;
    _capacityController.text = (count * 4).toString();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? _startDateTime : _endDateTime;

    // 1. 選日期
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null) return;

    // 2. 選時間
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startDateTime = newDateTime;
        // UX 優化：如果新的開始時間晚於結束時間，自動把結束時間往後推一小時
        if (_startDateTime.isAfter(_endDateTime)) {
          _endDateTime = _startDateTime.add(const Duration(hours: 1));
        }
      } else {
        // UX 優化：結束時間不能早於開始時間
        if (newDateTime.isBefore(_startDateTime)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('結束時間不能早於開始時間')));
          return;
        }
        _endDateTime = newDateTime;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await adminRepository.updateSession(
        // 🔥 使用 Model ID
        sessionId: widget.session.id,
        coachIds: _selectedCoachIds,
        location: _locationController.text,
        maxCapacity: int.tryParse(_capacityController.text),
        startTime: _startDateTime.toUtc(),
        endTime: _endDateTime.toUtc(),
      );

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
      title: const Text('編輯單一場次'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 時間選擇
              ListTile(
                title: const Text('開始時間'),
                subtitle: Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(_startDateTime),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => _pickDateTime(true),
              ),
              ListTile(
                title: const Text('結束時間'),
                subtitle: Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(_endDateTime),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => _pickDateTime(false),
              ),
              const Divider(height: 30),

              // 2. 地點
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '桌次 / 地點',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 教練多選
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '教練分配',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _allCoaches.map((coach) {
                  final coachId = coach['id'] as String;
                  final coachName = coach['full_name'] ?? '未命名';
                  final isSelected = _selectedCoachIds.contains(coachId);

                  return FilterChip(
                    label: Text(coachName),
                    selected: isSelected,
                    checkmarkColor: Colors.blue,
                    selectedColor: Colors.blue.shade100,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCoachIds.add(coachId);
                        } else {
                          _selectedCoachIds.remove(coachId);
                        }
                        _recalcCapacity();
                      });
                    },
                  );
                }).toList(),
              ),
              if (_allCoaches.isEmpty)
                const Text('暫無教練資料', style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 16),

              // 4. 人數上限
              TextField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '人數上限',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                  suffixText: '人',
                ),
              ),
            ],
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('更新', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
