import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/main.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final bool autoSendOnOpen;

  const ResetPasswordScreen({
    super.key,
    this.initialEmail,
    this.autoSendOnOpen = false,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  late final String _email;
  String? _otpErrorText;

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail?.trim() ?? '';
    if (widget.autoSendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resendOtp();
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
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
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _otpErrorText = '驗證碼需為 6 碼');
      _otpFocusNode.requestFocus();
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await authManager.verifyPasswordResetOtp(
        email: _email,
        otp: otp,
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
      appBar: AppBar(title: const Text('驗證 Email 驗證碼')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '帳號 Email',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(_email),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _otpFocusNode.requestFocus(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      final text = _otpController.text;
                      final char = index < text.length ? text[index] : '';
                      final isActive = _otpFocusNode.hasFocus &&
                          index == (text.length.clamp(0, 5));
                      return Container(
                        width: 48,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          char,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Offstage(
                  offstage: true,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) {
                      if (_otpErrorText != null) {
                        setState(() => _otpErrorText = null);
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                ),
                if (_otpErrorText != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _otpErrorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (_resendCountdown > 0 || _isResending)
                        ? null
                        : _resendOtp,
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
                        : const Text('確認驗證碼'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
