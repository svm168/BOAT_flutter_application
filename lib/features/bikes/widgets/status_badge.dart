import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isMissing = status.toLowerCase() == 'missing';
    final bgColor = isMissing
        ? AppColors.clay.withValues(alpha: 0.15)
        : AppColors.leaf.withValues(alpha: 0.15);
    final textColor = isMissing ? AppColors.clay : AppColors.moss;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isMissing ? 'Missing' : 'Active',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
