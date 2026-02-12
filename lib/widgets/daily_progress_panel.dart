import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DailyProgressPanel extends StatelessWidget {
  final Map<int, String> statuses;
  final bool isLoading;

  const DailyProgressPanel({
    super.key,
    required this.statuses,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: isLoading
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStep(context, 0, 'Morning'),
                _buildConnector(context, 0),
                _buildStep(context, 1, 'Afternoon'),
                _buildConnector(context, 1),
                _buildStep(context, 2, 'Evening'),
              ],
            ),
    );
  }

  Widget _buildStep(BuildContext context, int index, String label) {
    final status = statuses[index] ?? 'upcoming';
    final isCompleted = status == 'completed';
    final isActive = status == 'active';
    final isMissed = status == 'missed';

    Color color;

    if (isCompleted) {
      color = AppTheme.getSageColor(context); // Sage for completion
    } else if (isActive) {
      color = AppTheme.getPrimary(context); // Primary for active
    } else if (isMissed) {
      color = AppTheme.getMutedColor(
        context,
      ).withValues(alpha: 0.3); // Muted for missed
    } else {
      color = AppTheme.getBorderColor(context); // Muted border for upcoming
    }

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isActive ? color : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? color
                  : (isCompleted ? Colors.transparent : color),
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : isMissed
                ? Icon(
                    Icons.close,
                    size: 14,
                    color: AppTheme.getMutedColor(context),
                  )
                : isActive
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive
                ? AppTheme.getTextColor(context)
                : AppTheme.getMutedColor(
                    context,
                  ).withValues(alpha: isMissed ? 0.5 : 1.0),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(BuildContext context, int index) {
    final status = statuses[index] ?? 'upcoming';
    final isCompleted = status == 'completed';
    // final isActive = status == 'active';

    // If current step is completed, line continues as 'completed' color?
    // Or simpler: just gray line, but maybe colored if previous was completed?
    // Let's keep it simple: dashed if upcoming, solid if passed/completed?

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(
          top: 11,
        ), // Align with circle center (approx)
        color: isCompleted
            ? AppTheme.getSageColor(context).withValues(alpha: 0.5)
            : AppTheme.getBorderColor(context),
      ),
    );
  }
}
