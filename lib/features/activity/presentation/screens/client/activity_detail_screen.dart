import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/models/activity_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _activityRepository = ActivityRepository(Supabase.instance.client);
  ActivityModel? _activity;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      final activity = await _activityRepository.getActivityById(
        widget.activityId,
      );
      if (mounted) {
        setState(() {
          _activity = activity;
          _isLoading = false;
        });
      }
    } catch (e) {
      logError(e);
    }
  }

  Widget _buildImage(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    try {
      final imageBytes = base64Decode(base64Image);
      return LayoutBuilder(
        builder: (context, constraints) {
          return Image.memory(
            imageBytes,
            width: double.infinity,
            fit: BoxFit.contain, // 完整呈現圖片，保持原始比例
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      logError(e);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('活動詳情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('活動詳情')),
        body: const Center(child: Text('活動不存在')),
      );
    }

    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動詳情',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(_activity!.image),
              const SizedBox(height: 16),
              Text(
                _activity!.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(_activity!.startTime)} ~ ${dateFormat.format(_activity!.endTime)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _activity!.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
