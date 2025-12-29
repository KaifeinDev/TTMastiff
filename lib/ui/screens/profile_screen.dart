import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_repository.dart';
import '../../data/services/student_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authRepository = AuthRepository(Supabase.instance.client);
  final _studentRepository = StudentRepository(Supabase.instance.client);
   
  // 狀態變數
  List<StudentModel> _students = [];
  bool _isLoading = true;
   
  // 使用者資訊
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _avatarUrl;
  int _credits = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final metadata = user.userMetadata;
        
        // 抓取資料庫中的 Profile 資料
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        setState(() {
          _userEmail = user.email;
          _userName = metadata?['full_name'] ?? '用戶';
          _avatarUrl = metadata?['avatar_url'];
          _credits = profileData['credits'] ?? 0;
          _userPhone = profileData['phone'] ?? user.phone; 
        });

        await _refreshStudents();
        
      } catch (e) {
        debugPrint('載入使用者資料失敗: $e');
        await _refreshStudents();
      }
    }
  }

  Future<void> _refreshStudents() async {
    try {
      final students = await _studentRepository.getMyStudents();
      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確定要登出嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('登出', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _authRepository.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  // 🔒 顯示鎖定提示 (共用方法)
  void _showLockedDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    // ✅ 需求 2：檢查新增上限 (1位家長 + 3位小孩 = 4位)
    if (_students.length >= 4) {
      _showLockedDialog(
        '已達新增上限', 
        '為了確保服務品質，每個帳號最多新增 3 位子學員。\n\n如需新增更多成員，請洽詢場館管理員協助。'
      );
      return; // 直接結束，不跳出輸入視窗
    }

    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增學員'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('請輸入小孩或學員的姓名', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '姓名 / 暱稱',
                  hintText: '例如：王小明',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  await _performAddStudent(name);
                }
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performAddStudent(String name) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在建立學員資料...'), duration: Duration(seconds: 1)),
    );

    try {
      await _studentRepository.addStudent(name);
      await _refreshStudents();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 新增成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 新增失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(StudentModel student) {
    final nameController = TextEditingController(text: student.name);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('編輯名稱'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '姓名 / 暱稱',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != student.name) {
                  Navigator.pop(context);
                  await _performUpdateStudent(student.id, newName);
                } else {
                   Navigator.pop(context);
                }
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performUpdateStudent(String id, String newName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('更新資料中...'), duration: Duration(seconds: 1)),
    );

    try {
      await _studentRepository.updateStudent(id, newName);
      await _refreshStudents(); 
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 更新成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 更新失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的檔案'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: '登出',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 主帳號資訊卡片
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _avatarUrl == null 
                            ? Text(_userName?[0] ?? 'U', style: const TextStyle(fontSize: 24)) 
                            : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName ?? '未知用戶',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(_userEmail ?? '', style: Theme.of(context).textTheme.bodyMedium),
                              if (_userPhone != null && _userPhone!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.phone_iphone, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(_userPhone!, style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('主帳號 (家長)', style: TextStyle(fontSize: 12)),
                              )
                            ],
                          ),
                        ),
                        // ✅ 需求 1：主帳號資料鎖住 (顯示鎖頭圖示)
                        IconButton(
                          onPressed: () => _showLockedDialog(
                            '資料已鎖定', 
                            '為了確保會員權益與實名制安全，主帳號資料無法自行修改。\n\n如需變更，請洽櫃檯人員。'
                          ),
                          icon: const Icon(Icons.lock_outline, color: Colors.grey),
                          tooltip: '資料鎖定',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // 2. 錢包/點數區塊
                  Card(
                    elevation: 2,
                    color: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('剩餘點數', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              SizedBox(height: 4),
                              Text('Credits', style: TextStyle(color: Colors.white30, fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
                              const SizedBox(width: 8),
                              Text(
                                '$_credits',
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 32, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // 3. 學員管理
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline),
                          const SizedBox(width: 8),
                          Text(
                            '家庭成員 / 學員', 
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _showAddStudentDialog, // 裡面已經包含數量檢查
                        icon: const Icon(Icons.add),
                        label: const Text('新增'),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. 學員列表
                  if (_students.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('暫無資料'),
                    ))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _students.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final isSelf = student.name == _userName;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(student.avatarUrl ?? ''),
                              child: student.avatarUrl == null ? Text(student.name[0]) : null,
                            ),
                            title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: isSelf ? const Text('預設學員 (本人)') : const Text('子帳號'),
                            
                            // ✅ 需求 1 延伸：本人資料在列表中也鎖住，不能編輯
                            // ✅ 需求 3：不提供刪除按鈕 (這裡只給編輯，或如果是本人則給 null)
                            trailing: isSelf 
                              ? null // 本人連編輯按鈕都不顯示
                              : IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                                  onPressed: () => _showEditDialog(student),
                                ),
                            
                            onTap: isSelf 
                              ? null // 本人點擊無反應
                              : () => _showEditDialog(student),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
