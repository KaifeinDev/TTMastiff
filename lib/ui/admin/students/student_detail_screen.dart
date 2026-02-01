import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';

import '../../../data/models/student_model.dart';
import '../../../data/models/booking_model.dart';
import 'widgets/student_info_row.dart';
import 'widgets/student_status_chip.dart';
import 'widgets/student_avatar.dart';
import '../courses/widgets/session_edit_dialog.dart';
import '../../../core/utils/util.dart';
import 'package:ttmastiff/data/services/booking_repository.dart';
import '../../screens/widgets/level_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final StudentModel? initialStudent;
  final String? initialParentName;
  final String? initialParentPhone;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    this.initialStudent,
    this.initialParentName,
    this.initialParentPhone,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  // 將 DateFormat 設為靜態常量，避免每次 build 都創建新實例
  static final _dateFormat = DateFormat('yyyy/MM/dd (E)', 'zh_TW');
  static final _timeFormat = DateFormat('HH:mm');

  // 用來顯示即時點數與會員資訊
  StudentModel? _student;
  String? _parentName;
  String? _parentPhone;
  List<BookingModel> _bookings = [];
  int _parentCredits = 0;
  String? _membership; // profiles.membership
  int _points = 0; // 學員點數

  bool _isLoadingCredits = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
    BookingRepository.bookingRefreshSignal.addListener(_refreshAllData);
  }

  @override
  void dispose() {
    // 🔥 務必移除監聽，防止記憶體洩漏
    BookingRepository.bookingRefreshSignal.removeListener(_refreshAllData);
    super.dispose();
  }

  Future<void> _initData() async {
    if (widget.initialStudent != null) {
      _student = widget.initialStudent;
      _parentName = widget.initialParentName;
      _parentPhone = widget.initialParentPhone;
      _points = widget.initialStudent!.points;

      // 有資料就不用全頁 Loading，可以直接顯示內容
      if (mounted) setState(() => _isLoading = false);
    }
    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      // 這裡採用「並行執行」但「分開處理結果」的策略，比較安全
      final futures = <Future>[];

      // A. 必定要執行的任務
      futures.add(_fetchLatestBookings());
      futures.add(_loadParentCredits());

      // B. 只有當 _student 是 null (例如直接輸入網址) 才需要去抓學生資料
      //    或者你想要強制更新學生資料也可以放進來
      if (_student == null) {
        // 假設 studentRepository 有這個方法回傳 Map
        futures.add(
          studentRepository.fetchStudentAndParentProfile(widget.studentId),
        );
      }

      final results = await Future.wait(futures);

      // C. 處理學生資料回傳 (如果有的話)
      // 判斷邏輯：如果 _student 原本是 null，那 futures 最後一個一定是 fetchProfile 的結果
      if (_student == null && results.isNotEmpty) {
        // 取出最後一個結果
        final profileData = results.last as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _student = profileData['student'];
            _parentName = profileData['parentName'];
            _parentPhone = profileData['parentPhone'];
            _points = profileData['student']?.points ?? 0;
          });
        }
      } else if (_student != null) {
        // 如果已經有學生資料，更新點數
        if (mounted) {
          setState(() {
            _points = _student!.points;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadParentCredits() async {
    final targetParentId =
        _student?.parentId ?? widget.initialStudent?.parentId;

    if (targetParentId == null) return;

    try {
      final credits = await creditRepository.getCurrentCredit(targetParentId);

      // 讀取會員資格
      String? membership;
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('membership')
            .eq('id', targetParentId)
            .single();
        membership = profile['membership'] as String?;
      } catch (e) {
        debugPrint('讀取會員資格失敗: $e');
      }

      if (mounted) {
        setState(() {
          _parentCredits = credits;
          _membership = membership ?? 'beginner';
          _isLoadingCredits = false;
        });
      }
    } catch (e) {
      debugPrint('讀取點數失敗: $e');
    }
  }

  Future<void> _fetchLatestBookings() async {
    try {
      final newBookings = await bookingRepository.fetchBookingsByStudentId(
        widget.studentId,
      );

      if (mounted) {
        setState(() {
          _bookings = newBookings; // 更新列表
        });
      }
    } catch (e) {
      debugPrint('刷新預約失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('資料刷新失敗: $e')));
      }
    }
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;

    await Future.wait([
      _loadParentCredits(), // 重抓點數
      _fetchLatestBookings(), // 重抓列表
    ]);
  }

  // 顯示編輯會員等級 Dialog
  void _showLevelEditDialog() {
    final parentId = _student?.parentId ?? widget.initialStudent?.parentId;
    if (parentId == null) return;

    String? selectedLevel = _membership ?? 'beginner';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('編輯會員等級'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('初級'),
                  value: 'beginner',
                  groupValue: selectedLevel,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedLevel = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('中級'),
                  value: 'intermediate',
                  groupValue: selectedLevel,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedLevel = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('高級'),
                  value: 'advanced',
                  groupValue: selectedLevel,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedLevel = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  if (selectedLevel == null || selectedLevel == _membership) {
                    Navigator.of(dialogContext).pop();
                    return;
                  }

                  try {
                    await Supabase.instance.client
                        .from('profiles')
                        .update({'membership': selectedLevel})
                        .eq('id', parentId);
                    
                    // 更新本地狀態
                    setState(() {
                      _membership = selectedLevel!;
                    });

                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ 會員等級更新成功！')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ 更新失敗: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('確認'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 顯示編輯點數 Dialog
  void _showPointsEditDialog() {
    if (_student == null) return;

    int currentPoints = _points;
    final pointsController = TextEditingController(text: _points.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('編輯點數'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 32,
                      onPressed: () {
                        if (currentPoints > 0) {
                          setDialogState(() {
                            currentPoints--;
                            pointsController.text = currentPoints.toString();
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: pointsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            setDialogState(() {
                              currentPoints = int.tryParse(value) ?? 0;
                            });
                          } else {
                            setDialogState(() {
                              currentPoints = 0;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 32,
                      onPressed: () {
                        setDialogState(() {
                          currentPoints++;
                          pointsController.text = currentPoints.toString();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  if (currentPoints == _points) {
                    Navigator.of(dialogContext).pop();
                    return;
                  }

                  try {
                    await studentRepository.updateStudentPoints(
                      _student!.id,
                      currentPoints,
                    );

                    // 更新本地狀態
                    setState(() {
                      _points = currentPoints;
                      _student = StudentModel(
                        id: _student!.id,
                        parentId: _student!.parentId,
                        name: _student!.name,
                        avatarUrl: _student!.avatarUrl,
                        isPrimary: _student!.isPrimary,
                        level: _student!.level,
                        gender: _student!.gender,
                        medicalNote: _student!.medicalNote,
                        birthDate: _student!.birthDate,
                        points: currentPoints,
                      );
                    });

                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ 點數更新成功！')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ 更新失敗: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('確認'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 顯示儲值 Dialog
  void _showTopUpDialog(BuildContext context) {
    // 防呆：如果資料還沒載入完，不能開 Dialog
    if (_student == null) return;

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final pinController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currencyFormat = NumberFormat("#,##0", "en_US");
          return AlertDialog(
            title: Text('儲值點數 (${_parentName ?? "家長"})'), // 顯示家長名字
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '儲值金額/點數',
                    suffixText: '點',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0, // 按鈕之間的水平間距
                  runSpacing: 4.0, // 換行後的垂直間距
                  children: [100, 500, 1000].map((amount) {
                    return ActionChip(
                      label: Text('+$amount'),
                      backgroundColor: Colors.blue.shade50, // 淡淡的藍色背景
                      labelStyle: TextStyle(color: Colors.blue.shade700),
                      onPressed: () {
                        // 邏輯：取得當前數值，加上按鈕面額
                        final current =
                            int.tryParse(amountController.text) ?? 0;
                        final total = current + amount;
                        amountController.text = total.toString();
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: '備註 (選填)',
                    // 自動帶入學生姓名，方便以後查帳知道是為了誰儲值的
                    hintText: '例如：學生 ${_student!.name} 現金繳費',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  obscureText: true, // 隱藏密碼 (變星星/圓點)
                  keyboardType: TextInputType.number, // 只允許數字
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter
                        .digitsOnly, // 🔥 只允許輸入數字 (防止貼上文字)
                  ],
                  decoration: const InputDecoration(
                    labelText: '操作密碼 (PIN)',
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: '請輸入您的 PIN 碼',
                    border: OutlineInputBorder(),
                    errorStyle: TextStyle(color: Colors.red),
                    counterText: "",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final amountText = amountController.text;
                        final pinText = pinController.text; // PIN
                        if (amountText.isEmpty ||
                            int.tryParse(amountText) == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入有效的數字')),
                          );
                          return;
                        }
                        if (pinText.isEmpty || pinText.length != 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入完整操作密碼 (PIN)')),
                          );
                          return;
                        }

                        final amount = int.parse(amountText);
                        setDialogState(() => isLoading = true);

                        try {
                          // 🔥 重點：操作對象是 widget.parentId (Profile) 🔥

                          // 1. 呼叫 Repository 進行儲值
                          final newBalance = await creditRepository.addCredit(
                            userId: _student!.parentId, // 存入 Profile
                            amount: amount,
                            pin: pinText,
                            // 備註若為空，自動補上學生名字
                            description: descriptionController.text.isEmpty
                                ? '儲值 ${currencyFormat.format(amount)}'
                                : descriptionController.text,
                          );

                          if (mounted) {
                            setState(() {
                              _parentCredits = newBalance;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '成功儲值 $amount 點，目前餘額 $newBalance',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '儲值失敗: ${e.toString().replaceAll('Exception:', '')}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('確認儲值'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isSelf = _student!.isPrimary == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_student!.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 方案三：尊榮金幣風 ───
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左半部 (頭像與個資) - 維持不變
                      // 1. 左半部 (頭像與個資)
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            StudentAvatar(
                              avatarUrl: _student!.avatarUrl,
                              name: _student!.name,
                              radius: 32,
                            ),
                            const SizedBox(width: 12),

                            // 這裡的 Expanded 限制了文字區塊的最大寬度
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center, // 垂直置中
                                children: [
                                  // ─── 姓名 (加入 FittedBox) ───
                                  FittedBox(
                                    fit: BoxFit.scaleDown, // 空間不足時縮小
                                    alignment:
                                        Alignment.centerLeft, // 🔥 關鍵：縮小時靠左對齊
                                    child: Text(
                                      _student!.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1, // 強制單行，觸發縮小機制
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 中間分隔線
                      Container(
                        height: 50,
                        width: 1,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),

                      // 🔥 右半部：方案三 (Gold) 🔥
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                _isLoadingCredits
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            NumberFormat(
                                              '#,###',
                                            ).format(_parentCredits),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                            Text(
                              'Credits',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),
                            SizedBox(
                              height: 24,
                              child: TextButton.icon(
                                onPressed: () => _showTopUpDialog(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerRight,
                                ),
                                icon: const Icon(Icons.add_card, size: 14),
                                label: const Text(
                                  '儲值',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 下半部資訊 (維持不變)
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  StudentInfoRow(
                    icon: Icons.cake,
                    label: '生日',
                    value: _student!.birthDate.toDateWithAge(),
                  ),
                  if (!isSelf) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.person,
                      label: '家長',
                      value: _parentName ?? '未提供',
                    ),
                  ],
                  const SizedBox(height: 12),
                  StudentInfoRow(
                    icon: Icons.phone,
                    label: isSelf ? '電話' : '電話',
                    value: _parentPhone ?? '未提供',
                  ),
                  if (_student!.medicalNote != null &&
                      _student!.medicalNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.medical_information,
                      label: '醫療備註',
                      value: _student!.medicalNote!,
                    ),
                  ],
                  if (isSelf) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.wallet_membership,
                      label: '會員',
                      value: getLevelText(_membership),
                      onEdit: () => _showLevelEditDialog(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  StudentInfoRow(
                    icon: Icons.stars,
                    label: '點數',
                    value: '$_points',
                    onEdit: () => _showPointsEditDialog(),
                  ),
                ],  
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 報名課程列表
          Text(
            '報名課程 (${_bookings.length})',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_bookings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '尚未報名任何課程',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            )
          else
            ..._bookings.map((booking) {
              final session = booking.session;
              final course = session.course;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: course != null
                      ? () {
                          // 直接打開該場次的對話框
                          final category = course.category;
                          showDialog(
                            context: context,
                            builder: (dialogContext) => SessionEditDialog(
                              session: session,
                              category: category,
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course?.title ?? '未知課程',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (course != null)
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_dateFormat.format(session.startTime)} ${_timeFormat.format(session.startTime)} - ${_timeFormat.format(session.endTime)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '\$${booking.priceSnapshot}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            StudentStatusChip(status: booking.attendanceStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
