import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/provider_response.dart';
import '../../../domain/models/service_request.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory StatusBadge.fromRequestStatus(RequestStatus status) {
    return switch (status) {
      RequestStatus.open => StatusBadge(
          label: status.label,
          color: AppColors.info,
          icon: Icons.radio_button_checked_rounded,
        ),
      RequestStatus.quoted => StatusBadge(
          label: status.label,
          color: AppColors.accentAmber,
          icon: Icons.local_offer_rounded,
        ),
      RequestStatus.inProgress => StatusBadge(
          label: status.label,
          color: AppColors.primary,
          icon: Icons.engineering_rounded,
        ),
      RequestStatus.completed => StatusBadge(
          label: status.label,
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        ),
      RequestStatus.cancelled => StatusBadge(
          label: status.label,
          color: AppColors.error,
          icon: Icons.cancel_rounded,
        ),
    };
  }

  factory StatusBadge.fromQuoteStatus(QuoteStatus status) {
    return switch (status) {
      QuoteStatus.pending => StatusBadge(
          label: status.label,
          color: AppColors.info,
          icon: Icons.hourglass_top_rounded,
        ),
      QuoteStatus.negotiating => StatusBadge(
          label: status.label,
          color: AppColors.accentAmber,
          icon: Icons.forum_rounded,
        ),
      QuoteStatus.accepted => StatusBadge(
          label: status.label,
          color: AppColors.success,
          icon: Icons.verified_rounded,
        ),
      QuoteStatus.declined => StatusBadge(
          label: status.label,
          color: Colors.grey,
          icon: Icons.close_rounded,
        ),
    };
  }

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
