import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum ConfirmationTone { success, warning, info }

class ConfirmationBannerData {
  const ConfirmationBannerData({
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.tone = ConfirmationTone.success,
    this.icon,
  });

  final String title;
  final String subtitle;
  final String? badgeText;
  final ConfirmationTone tone;
  final IconData? icon;
}

/// Reusable, responsive confirmation banner displayed after stateful actions
/// (order placed, cancelled & refunded, rescheduled, completed, etc.).
class ConfirmationBanner extends StatelessWidget {
  const ConfirmationBanner({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  final ConfirmationBannerData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (Color accent, IconData defaultIcon) = switch (data.tone) {
      ConfirmationTone.success => (AppColors.success, Icons.check_circle_rounded),
      ConfirmationTone.warning => (AppColors.warning, Icons.info_rounded),
      ConfirmationTone.info => (AppColors.info, Icons.verified_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.42), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon ?? defaultIcon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      data.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    if (data.badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data.badgeText!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
