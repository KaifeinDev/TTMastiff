import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:intl/intl.dart';
import 'gender_icon.dart';
import 'membership_utils.dart';

/// 個人資訊卡共用元件
/// 用於 profile, homepage, student_detail_screen
class UserInfoCard extends StatelessWidget {
  final String displayName;
  final String? gender;
  final String? email;
  final String? phone;
  final String? membership;
  final int? points; // 學員點數（僅 admin 顯示）
  final int? credits; // Credits（僅 admin 顯示）
  final bool isLoadingCredits; // Credits 載入狀態
  final Widget? trailingAction; // 例如鎖定按鈕
  final bool showLockButton; // 是否顯示鎖定按鈕
  final VoidCallback? onLockTap; // 鎖定按鈕點擊回調
  final bool isAdmin; // 是否為 admin 頁面
  final bool isSelf; // 是否為本人
  final VoidCallback? onMembershipEdit; // 編輯會員等級回調（僅 admin 且本人）
  final VoidCallback? onPointsEdit; // 編輯點數回調（僅 admin）
  final VoidCallback? onCreditsTopUp; // 儲值回調（僅 admin 且本人）
  // 額外資訊（僅 admin 顯示）
  final String? birthDateText; // 生日文字（已格式化）
  final String? parentName; // 家長名稱
  final String? medicalNote; // 醫療備註
  final EdgeInsets? padding; // 自訂 padding
  final bool moveAvatarToTopRight; // 手機介面將頭像移到右上角（僅 student_detail_screen）
  final bool isPrimary; // 是否為本人（用於頭像顏色）

  const UserInfoCard({
    super.key,
    required this.displayName,
    this.gender,
    this.email,
    this.phone,
    this.membership,
    this.points,
    this.credits,
    this.isLoadingCredits = false,
    this.trailingAction,
    this.showLockButton = false,
    this.onLockTap,
    this.isAdmin = false,
    this.isSelf = false,
    this.onMembershipEdit,
    this.onPointsEdit,
    this.onCreditsTopUp,
    this.birthDateText,
    this.parentName,
    this.medicalNote,
    this.padding,
    this.moveAvatarToTopRight = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim();
    final initials = name.length >= 2 ? name.substring(name.length - 2) : name;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final shouldMoveAvatar = moveAvatarToTopRight && isMobile;

    final avatar = CircleAvatar(
      radius: 30,
      backgroundColor: isPrimary
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 20,
          color: isPrimary
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: shouldMoveAvatar
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          if (gender != null) ...[
                            const SizedBox(width: 4),
                            GenderIcon(gender: gender),
                          ],
                        ],
                      ),
                    ),
                    avatar,
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRows(context),
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          if (gender != null) ...[
                            const SizedBox(width: 4),
                            GenderIcon(gender: gender),
                          ],
                        ],
                      ),
                      _buildInfoRows(context),
                    ],
                  ),
                ),
                if (trailingAction != null)
                  trailingAction!
                else if (showLockButton)
                  IconButton(
                    onPressed: onLockTap,
                    icon: const Icon(Icons.lock_outline, color: Colors.grey),
                    tooltip: '資料鎖定',
                  ),
              ],
            ),
    );
  }

  Widget _buildInfoRows(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Email（非 admin 頁面不顯示標題，admin 頁面顯示標題）
        if (email != null && email!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.email, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                if (isAdmin)
                  Text(
                    isSelf ? '信箱: ' : '家長信箱: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Expanded(
                  child: Text(
                    email!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // 2. Phone（非 admin 頁面不顯示標題，admin 頁面顯示標題）
        if (phone != null && phone!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.phone_iphone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                if (isAdmin)
                  Text(
                    isSelf ? '手機: ' : '家長手機: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  phone!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        // 3. Birthday（生日）
        if (isAdmin && birthDateText != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(Icons.cake, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '生日: ',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  birthDateText!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        // 4. Membership（非 admin 頁面不顯示標題，admin 頁面顯示標題）
        if (membership != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(
                  Icons.wallet_membership,
                  size: 16,
                  color: (isAdmin && isSelf) ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 8),
                if (isAdmin)
                  Text(
                    '會員: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  getLevelText(membership),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isAdmin && isSelf && onMembershipEdit != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onMembershipEdit,
                  ),
                ],
              ],
            ),
          ),
        // 5. Points（點數，都可以編輯）
        if (isAdmin && points != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.stars, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '點數: ',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onPointsEdit != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onPointsEdit,
                  ),
                ],
              ],
            ),
          ),
        // 6. Credits（儲值，本人可編輯，非本人只要顯示）
        if (isAdmin && credits != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  size: 16,
                  color: isSelf ? Colors.amber : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Credits: ',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                isLoadingCredits
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        NumberFormat('#,###').format(credits),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                if (isSelf && onCreditsTopUp != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onCreditsTopUp,
                  ),
                ],
              ],
            ),
          ),
        // 7. Medical Note（醫療備註，有的話再顯示）
        if (isAdmin && medicalNote != null && medicalNote!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.medical_information,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  '醫療備註: ',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    medicalNote!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
