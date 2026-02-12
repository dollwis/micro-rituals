import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RitualTimeSlider extends StatelessWidget {
  final TimeOfDay startTime;
  final TimeOfDay endTime; // Can be smaller than startTime if crossing midnight
  final TimeOfDay currentTime;
  final ValueChanged<TimeOfDay> onChanged;
  final bool isEnabled;

  const RitualTimeSlider({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.currentTime,
    required this.onChanged,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate total minutes in the window
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes < startMinutes) {
      // Crosses midnight, add 24 hours to end
      endMinutes += 24 * 60;
    }

    int totalWindowMinutes = endMinutes - startMinutes;

    // 2. Calculate current minutes relative to start (handling midnight wrap)
    int currentMinutes = currentTime.hour * 60 + currentTime.minute;
    if (currentMinutes < startMinutes && endTime.hour < startTime.hour) {
      // If current is e.g. 01:00 and start is 18:00, treat 01:00 as next day
      currentMinutes += 24 * 60;
    }

    // Clamp current to window (just in case)
    if (currentMinutes < startMinutes) currentMinutes = startMinutes;
    if (currentMinutes > endMinutes) currentMinutes = endMinutes;

    double value = (currentMinutes - startMinutes).toDouble();

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.getPrimary(context),
              inactiveTrackColor: AppTheme.getPrimary(
                context,
              ).withValues(alpha: 0.2),
              thumbColor: AppTheme.getPrimary(context),
              overlayColor: AppTheme.getPrimary(context).withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: totalWindowMinutes.toDouble(),
              divisions: (totalWindowMinutes / 5).round(), // 5-minute snap
              label: _formatTime(currentTime, context),
              onChanged: isEnabled
                  ? (val) {
                      int newTotalMinutes = startMinutes + val.round();
                      // Normalize back to 0-24h
                      if (newTotalMinutes >= 24 * 60) {
                        newTotalMinutes -= 24 * 60;
                      }

                      final newTime = TimeOfDay(
                        hour: newTotalMinutes ~/ 60,
                        minute: newTotalMinutes % 60,
                      );
                      onChanged(newTime);
                    }
                  : null,
            ),
          ),

          // Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(startTime, context),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getMutedColor(context),
                  ),
                ),
                Text(
                  _formatTime(currentTime, context), // Current Value
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getPrimary(context),
                  ),
                ),
                Text(
                  _formatTime(endTime, context),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time, BuildContext context) {
    return time.format(context);
  }
}
