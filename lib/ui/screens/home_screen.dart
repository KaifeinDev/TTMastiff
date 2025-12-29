import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/session_repository.dart';
// 記得引入你的 Detail Screen
import 'course_detail_screen.dart'; 
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionRepo = SessionRepository(Supabase.instance.client);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<SessionModel> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchSessions(_selectedDate);
  }

  Future<void> _fetchSessions(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _isLoading = true;
    });
    try {
      final sessions = await _sessionRepo.fetchSessionsByDate(date);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  // 🔄 改動: 使用 GoRouter 進行頁面跳轉
  void _onSessionTap(SessionModel session) {
    // 使用 context.push 配合我们在 router.dart 設定的路徑
    // extra: session 將整包資料傳遞給 CourseDetailScreen
    context.push('/home/course_detail', extra: session).then((_) {
      // 當使用者從詳情頁返回時，重新整理列表 (例如名額可能變動)
      _fetchSessions(_selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('桌球課程預約'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 📅 星期選擇器
          _WeekDaySelector(
            selectedDate: _selectedDate,
            onDateSelected: _fetchSessions,
          ),
          
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? _EmptyState(date: _selectedDate)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _SessionCard(
                            session: _sessions[index],
                            onTap: () => _onSessionTap(_sessions[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// 📅 元件：優化後的星期選擇器 (強調星期幾)
class _WeekDaySelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _WeekDaySelector({required this.selectedDate, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    // 顯示未來 7 天 (一週)
    final dates = List.generate(7, (index) => DateTime.now().add(Duration(days: index)));

    return Container(
      height: 100, 
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          
          // 格式化星期幾 (例如：週一, Mon)
          final weekDay = DateFormat('E', 'zh_TW').format(date);
          final dayStr = DateFormat('M/d').format(date); 

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekDay,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 🏓 元件：課程卡片
class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final isPersonal = session.category == 'personal';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左側：大時間顯示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(timeFormat.format(session.startTime),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('至', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    Text(timeFormat.format(session.endTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 中間：課程資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(
                          text: session.categoryText,
                          color: isPersonal ? Colors.orange : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        if (session.coachesText.isNotEmpty)
                          Text(
                             session.coachesText,
                             style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.courseTitle,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${session.price}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final MaterialColor color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade100),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade700),
      ),
    );
  }
}

// 🥶 元件：空狀態
class _EmptyState extends StatelessWidget {
  final DateTime date;
  const _EmptyState({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            '本週 ${DateFormat('E', 'zh_TW').format(date)} 沒有安排課程',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
