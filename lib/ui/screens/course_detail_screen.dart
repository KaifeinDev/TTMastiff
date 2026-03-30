import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/main.dart';

// Models & Repositories
import '../../data/models/session_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/course_model.dart';
import 'widgets/level_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  // Data
  CourseModel? _course;
  List<SessionModel> _upcomingSessions = [];
  List<StudentModel> _myStudents = [];

  // 會員等級 (beginner / intermediate / advanced)
  String? _memberLevel;

  // UI State
  bool _isLoading = true;
  bool _isBooking = false; // 防止重複點擊

  // Selection State
  final Set<String> _selectedStudentIds = {};
  final Set<String> _selectedSessionIds = {};

  String _formatStudentNames(List<StudentModel> students) {
    if (students.isEmpty) return '';
    if (students.length <= 5) {
      return students.map((s) => s.name).join('、');
    }
    final first = students.take(5).map((s) => s.name).join('、');
    return '$first 等 ${students.length} 人';
  }

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 平行請求資料以提升速度
      final results = await Future.wait([
        courseRepository.fetchCourseById(widget.courseId),
        courseRepository.fetchUpcomingSessionsByCourseId(widget.courseId),
        studentRepository.getMyStudents(),
      ]);

      // 取得會員等級（從 profiles.membership）
      String? membership;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('membership')
              .eq('id', user.id)
              .single();
          membership = profile['membership'] as String?;
        } catch (e, st) {
          logError(e, st);
        }
      }

      if (mounted) {
        setState(() {
          _course = results[0] as CourseModel;
          _upcomingSessions = results[1] as List<SessionModel>;
          _myStudents = results[2] as List<StudentModel>;
          _memberLevel = membership ?? 'beginner';

          // UX 優化：預設選取「主要學員」
          // if (_myStudents.isNotEmpty) {
          //   final primaryStudent = _myStudents.firstWhere(
          //     (s) => s.isPrimary,
          //     orElse: () => _myStudents.first,
          //   );
          //   _selectedStudentIds.add(primaryStudent.id);
          // }

          // UX 優化：預設選取「未來 0 堂還沒額滿的課」
          final availableSessions = _upcomingSessions
              .where((s) => !s.isFull)
              .take(0)
              .map((e) => e.id);
          _selectedSessionIds.addAll(availableSessions);

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, e, prefix: '載入失敗：');
      }
    }
  }

  /// 💰 計算總金額（含會員折扣）
  /// 邏輯：(所選 Session 的折扣後價格總和) * (所選學生人數)
  int get _totalCost => _discountedTotalCost;

  Future<void> _onBatchBookPressed() async {
    if (_selectedStudentIds.isEmpty || _selectedSessionIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一位學員和一堂課程')));
      return;
    }

    setState(() => _isBooking = true);

    try {
      // Phase 1：批次報名點數不足的前端攔截
      final int sessionCount = _selectedSessionIds.length;
      final int perStudentCost = _course!.price * sessionCount;

      final List<StudentModel> selectedStudents = _myStudents
          .where((s) => _selectedStudentIds.contains(s.id))
          .toList();

      final Set<String> parentIds =
          selectedStudents.map((s) => s.parentId).toSet();

      final creditsEntries = await Future.wait(
        parentIds.map(
          (parentId) async => MapEntry(
            parentId,
            await creditRepository.getCurrentCredit(parentId),
          ),
        ),
      );

      final Map<String, int> remainingCredits =
          Map.fromEntries(creditsEntries);

      final List<StudentModel> eligibleStudents = [];
      final List<StudentModel> insufficientStudents = [];

      // 逐位分配預算：同一個 parentId 可能對應多位學生
      for (final student in selectedStudents) {
        final remaining = remainingCredits[student.parentId] ?? 0;
        if (remaining >= perStudentCost) {
          eligibleStudents.add(student);
          remainingCredits[student.parentId] = remaining - perStudentCost;
        } else {
          insufficientStudents.add(student);
        }
      }

      if (eligibleStudents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                '餘額不足，無法完成批次報名。\n略過：${_formatStudentNames(insufficientStudents)}',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final List<String> eligibleStudentIds =
          eligibleStudents.map((s) => s.id).toList();

      // 呼叫 Repository 進行批量寫入（僅針對餘額足夠者）
      final result = await bookingRepository.createBatchBooking(
        sessionIds: _selectedSessionIds.toList(),
        studentIds: eligibleStudentIds,
        // 這裡傳入課程原價作為快照，或是後端會再驗證一次價格
        priceSnapshot: _course!.price,
      );
      final successCount = result['success'] ?? 0;
      final skippedCount = result['skipped'] ?? 0;
      final totalCost = result['totalCost'] ?? 0;

      if (mounted) {
        String message = '報名作業完成！\n成功: $successCount 堂，扣除 $totalCost 點';
        Color snackBarColor;

        if (successCount > 0) {
          // A. 有成功新增 (綠色)
          snackBarColor = Colors.green;
          message = '報名作業完成！\n成功: $successCount 堂，扣除 $totalCost 點';

          if (skippedCount > 0) {
            message += '\n(另有 $skippedCount 堂因重複而略過)';
          }

          if (insufficientStudents.isNotEmpty) {
            message +=
                '\n(另有 ${insufficientStudents.length} 位餘額不足：${_formatStudentNames(insufficientStudents)} 已略過)';
          }
        } else {
          // B. 全部都是重複，沒有任何變動 (灰色)
          snackBarColor = Colors.grey.shade700;
          message = '沒有新增任何報名\n(所有選擇的項目皆已報名過)';

          if (insufficientStudents.isNotEmpty) {
            message +=
                '\n(另有 ${insufficientStudents.length} 位餘額不足：${_formatStudentNames(insufficientStudents)} 已略過)';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: snackBarColor,
            duration: const Duration(seconds: 3),
          ),
        );
        // 清空選擇 & 刷新資料
        setState(() {
          if (insufficientStudents.isEmpty) {
            _selectedStudentIds.clear();
            _selectedSessionIds.clear();
          } else {
            // 只移除已成功可扣款的學生；餘額不足的學生保留供後續儲值後重試
            _selectedStudentIds.removeAll(eligibleStudentIds);
          }
        });
        _loadData();
        // Navigator.pop(context); // 回到上一頁
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBooking = false);
        showErrorSnackBar(context, e, prefix: '報名失敗：');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_course == null) {
      return const Scaffold(body: Center(child: Text('找不到課程資料')));
    }

    final dateFormat = DateFormat('MM/dd (E)', 'zh_TW');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _course!.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. 課程圖片與資訊
                Text(
                  "詳細課程資訊",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildHeaderSection(),
                const SizedBox(height: 24),

                // 2. 選擇學員
                Text(
                  "選擇上課學員",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStudentSelector(),

                const Divider(height: 48, thickness: 1),

                // 3. 選擇場次
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "選擇上課日期",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedSessionIds.isNotEmpty)
                      Text(
                        "已選 ${_selectedSessionIds.length} 堂",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_upcomingSessions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text(
                      "目前沒有開放報名的場次",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ..._upcomingSessions.map((session) {
                    return _buildSessionTile(session, dateFormat, timeFormat);
                  }),

                // 底部留白，避免被浮動按鈕擋住 (如果有的話)
                const SizedBox(height: 20),
              ],
            ),
          ),

          // 4. 底部結帳區
          _buildBottomBar(),
        ],
      ),
    );
  }

  // === UI 組件拆分 ===

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_course!.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _course!.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 16),
        // 標籤
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _course!.category == 'personal'
                ? Colors.purple.shade50
                : Color.fromARGB(30, 255, 122, 50),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _course!.category == 'personal' ? '一對一' : '團體班',
            style: TextStyle(
              fontSize: 12,
              color: _course!.category == 'personal'
                  ? Colors.purple
                  : const Color.fromARGB(255, 255, 123, 0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Builder(
        builder: (_) {
          final description = (_course!.description?.trim().isNotEmpty ?? false)
              ? _course!.description!.trim()
              : "暫無課程描述";
          return Text(
            description,
          style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          );
        },
        ),
      ],
    );
  }

  Widget _buildStudentSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _myStudents.map((student) {
        final isSelected = _selectedStudentIds.contains(student.id);
        return FilterChip(
          label: Text(student.name),
          selected: isSelected,
          checkmarkColor: Colors.white,
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          avatar: CircleAvatar(
            backgroundColor: isSelected ? Colors.white24 : Colors.grey.shade200,
            child: Text(
              student.name.isNotEmpty ? student.name[0] : 'S',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedStudentIds.add(student.id);
              } else {
                _selectedStudentIds.remove(student.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSessionTile(
    SessionModel session,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    final isSelected = _selectedSessionIds.contains(session.id);
    // 檢查是否額滿 (利用 SessionModel 的屬性)
    final isFull = session.isFull;
    final remain = session.maxCapacity - session.bookingsCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isFull ? Colors.grey.shade50 : Colors.white,
        border: Border.all(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        enabled: !isFull, // 額滿則禁用
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        activeColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Text(
              dateFormat.format(session.startTime),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFull ? Colors.grey : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            // 顯示剩餘名額標籤
            if (isFull)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "額滿",
                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            else if (remain <= 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "剩 $remain 位",
                  style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              "${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}",
              style: TextStyle(
                color: isFull ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            // 顯示單堂價格
            _buildSessionPrice(session, isFull),
          ],
        ),
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _selectedSessionIds.add(session.id);
            } else {
              _selectedSessionIds.remove(session.id);
            }
          });
        },
      ),
    );
  }

  /// 根據會員等級計算單堂價格折扣，並顯示折扣標籤
  Widget _buildSessionPrice(SessionModel session, bool isFull) {
    final basePrice = session.displayPrice;
    final finalPrice = getDiscountedPrice(basePrice, _memberLevel);
    final discountLabel = getDiscountLabel(_memberLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "\$$finalPrice",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFull ? Colors.grey : Colors.black87,
          ),
        ),
        if (discountLabel != null)
          Text(
            discountLabel,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  /// 計算套用會員折扣後的總價
  int get _discountedTotalCost {
    int sessionsTotal = 0;
    for (var sessionId in _selectedSessionIds) {
      final session = _upcomingSessions.firstWhere((s) => s.id == sessionId);
      final discounted = getDiscountedPrice(session.displayPrice, _memberLevel);
      sessionsTotal += discounted;
    }
    return sessionsTotal * _selectedStudentIds.length;
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "總計金額",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    "\$$_totalCost",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed:
                  (_isBooking ||
                      _selectedStudentIds.isEmpty ||
                      _selectedSessionIds.isEmpty)
                  ? null
                  : _onBatchBookPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      "確認報名 (${_selectedSessionIds.length * _selectedStudentIds.length})",
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
