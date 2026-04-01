import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/main.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  late final String _email;

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail?.trim() ?? '';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown -= 1);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_email.isEmpty || !_email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入有效的 Email')));
      return;
    }
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await authManager.sendPasswordResetOtp(_email);
      if (!mounted) return;
      _startResendCountdown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已重新寄送驗證碼')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重寄失敗：$e')));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _isVerifying = true);
    try {
      await authManager.verifyPasswordResetOtp(
        email: _email,
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      context.push('/reset-password/new');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('驗證失敗：$e')));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_email.isEmpty || !_email.contains('@')) {
      return Scaffold(
        appBar: AppBar(title: const Text('重設密碼')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('缺少有效 Email，請從登入頁重新操作。'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('回登入頁'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('驗證 Email OTP')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '帳號 Email',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_email),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: '6 碼驗證碼',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '請輸入驗證碼';
                      if (v.trim().length != 6) return '驗證碼需為 6 碼';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          (_resendCountdown > 0 || _isResending) ? null : _resendOtp,
                      child: Text(
                        _resendCountdown > 0
                            ? '重寄驗證碼 (${_resendCountdown}s)'
                            : (_isResending ? '寄送中...' : '重寄驗證碼'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isVerifying ? null : _verifyOtp,
                      child: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('驗證 OTP'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
