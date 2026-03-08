import 'package:flutter/material.dart';

import '../../domain/entities/chat_user_entity.dart';

/// Grup formu için paylaşılan model ve widget'lar.
class MemberRole {
  MemberRole(this.friend) : role = null;
  final ChatUserEntity friend;
  String? role;
}

const List<String> kGroupColorOptions = [
  '#6366F1', '#0EA5E9', '#10B981',
  '#F97316', '#EF4444', '#8B5CF6',
  '#EC4899', '#14B8A6',
];

/// (value, label, icon, color)
const List<(String, String, IconData, Color)> kRoleOptions = [
  ('yonetici', 'Yönetici', Icons.admin_panel_settings_rounded, Color(0xFFEF4444)),
  ('kıdemli', 'Kıdemli', Icons.star_rounded, Color(0xFFF59E0B)),
  ('uye', 'Üye', Icons.person_rounded, Color(0xFF10B981)),
];

class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.65)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class GlassInfo extends StatelessWidget {
  const GlassInfo({
    super.key,
    required this.icon,
    required this.text,
    this.isWarning = false,
  });

  final IconData icon;
  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? const Color(0xFFF59E0B) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.80), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class FriendRoleTile extends StatelessWidget {
  const FriendRoleTile({
    super.key,
    required this.friend,
    required this.isSelected,
    required this.selectedRole,
    required this.onToggle,
    required this.onRoleChanged,
  });

  final ChatUserEntity friend;
  final bool isSelected;
  final String? selectedRole;
  final VoidCallback onToggle;
  final ValueChanged<String> onRoleChanged;

  String get _roleLabel => switch (selectedRole) {
        'yonetici' => 'Yönetici',
        'kıdemli' => 'Kıdemli',
        'uye' => 'Üye',
        _ => 'Rol Seç',
      };

  Color get _roleColor => switch (selectedRole) {
        'yonetici' => const Color(0xFFEF4444),
        'kıdemli' => const Color(0xFFF59E0B),
        'uye' => const Color(0xFF10B981),
        _ => Colors.white,
      };

  IconData get _roleIcon => switch (selectedRole) {
        'yonetici' => Icons.admin_panel_settings_rounded,
        'kıdemli' => Icons.star_rounded,
        'uye' => Icons.person_rounded,
        _ => Icons.badge_outlined,
      };

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.20), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B40F0).withValues(alpha: 0.40),
                blurRadius: 30,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(int.parse(
                            friend.avatarColorHex.replaceFirst('#', '0xFF')))
                        .withValues(alpha: 0.80),
                    child: Text(
                      friend.initials,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                        Text(
                          'Rol Ata',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close,
                        color: Colors.white.withValues(alpha: 0.55), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 12),
              ...kRoleOptions.map((opt) {
                final isActive = selectedRole == opt.$1;
                return GestureDetector(
                    onTap: () {
                    if (!isSelected) onToggle();
                    onRoleChanged(opt.$1);
                    Navigator.of(context).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? opt.$4.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? opt.$4.withValues(alpha: 0.70)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: opt.$4.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(opt.$3, color: opt.$4, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.$2,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                switch (opt.$1) {
                                  'yonetici' =>
                                    'Grubu yönetir, üye ekler/çıkarır',
                                  'kıdemli' => 'Görev ekleyip düzenleyebilir',
                                  _ => 'Grubu görüntüler ve görev ekler',
                                },
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.50),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle_rounded,
                              color: opt.$4, size: 20)
                        else
                          Icon(Icons.radio_button_unchecked,
                              color: Colors.white.withValues(alpha: 0.30),
                              size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor =
        Color(int.parse(friend.avatarColorHex.replaceFirst('#', '0xFF')));
    final hasRole = selectedRole != null;
    final needsRole = isSelected && !hasRole;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: needsRole
                ? Colors.orange.withValues(alpha: 0.65)
                : isSelected
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B40F0)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B40F0)
                        : Colors.white.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor.withValues(alpha: 0.80),
              child: Text(
                friend.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  Text(
                    friend.email,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showRoleDialog(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasRole
                      ? _roleColor.withValues(alpha: 0.85)
                      : needsRole
                          ? Colors.orange.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasRole
                        ? _roleColor
                        : needsRole
                            ? Colors.orange.withValues(alpha: 0.70)
                            : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasRole ? _roleIcon : Icons.badge_outlined,
                      color: hasRole
                          ? Colors.white
                          : needsRole
                              ? Colors.orange.shade300
                              : Colors.white.withValues(alpha: 0.65),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _roleLabel,
                      style: TextStyle(
                        color: hasRole
                            ? Colors.white
                            : needsRole
                                ? Colors.orange.shade300
                                : Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: hasRole ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down,
                      color: hasRole
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.50),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareButton extends StatelessWidget {
  const ShareButton({
    super.key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
