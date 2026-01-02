import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 確保路徑正確
import 'package:ttmastiff/data/services/course_repository.dart';
import 'package:ttmastiff/data/models/session_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CourseRepository _courseRepo;
  late Future<List<SessionModel>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _courseRepo = CourseRepository(Supabase.instance.client);
    _refreshSessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessionsFuture = _courseRepo.fetchUpcomingSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('近期課程'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50], // 微微的灰底，讓卡片更突出
      body: RefreshIndicator(
        onRefresh: () async => _refreshSessions(),
        child: FutureBuilder<List<SessionModel>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('發生錯誤: ${snapshot.error}'));
            }

            final sessions = snapshot.data ?? [];

            if (sessions.isEmpty) {
              return const Center(child: Text('目前沒有即將開始的課程'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _SessionCard(session: sessions[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final course = session.course;
    if (course == null) return const SizedBox.shrink();

    final fmtDate = DateFormat('MM/dd (E)', 'zh_TW');
    final fmtTime = DateFormat('HH:mm');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // 導航：傳遞 ID
          context.push('/home/course_detail/${session.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 圖片區塊
            Container(
              height: 140,
              width: double.infinity,
              color: Colors.grey[200],
              child: course.imageUrl != null
                  ? Image.network(
                      course.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.grey),
                    )
                  : const Icon(Icons.sports_basketball, size: 50, color: Colors.grey),
            ),
            
            // 2. 資訊區塊
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${fmtDate.format(session.startTime)} ${fmtTime.format(session.startTime)} - ${fmtTime.format(session.endTime)}',
                        style: TextStyle(color: Colors.grey[800], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 地點
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                session.location ?? '地點未定',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 價格
                      Text(
                        'NT\$ ${course.price}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
