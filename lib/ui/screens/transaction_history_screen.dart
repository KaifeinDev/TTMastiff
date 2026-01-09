import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 需要先 pub add intl
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/credit_repository.dart';
import '../../data/models/transaction_model.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late final CreditRepository _creditRepo;
  late Future<List<TransactionModel>> _futureTransactions;

  @override
  void initState() {
    super.initState();
    _creditRepo = CreditRepository(Supabase.instance.client);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _futureTransactions = _creditRepo.fetchTransactions(userId);
    } else {
      _futureTransactions = Future.error('未登入');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('交易明細')),
      body: FutureBuilder<List<TransactionModel>>(
        future: _futureTransactions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          }

          final transactions = snapshot.data ?? [];
          if (transactions.isEmpty) {
            return const Center(child: Text('目前沒有交易紀錄'));
          }

          return ListView.separated(
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = transactions[index];
              final isPositive = item.amount >= 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPositive
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Icon(
                    isPositive ? Icons.add : Icons.remove,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(item.description ?? '無描述'),
                subtitle: Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt),
                ),
                trailing: Text(
                  '${isPositive ? "+" : ""}${item.amount}',
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
