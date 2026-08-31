import 'package:flutter/material.dart';

class DailyProgressCard extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final DateTime selectedDate;

  const DailyProgressCard({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final int percentage = (progress * 100).toInt();

    String title;
    String subtitle;
    if (totalCount == 0) {
      title = 'No Habits Scheduled';
      subtitle = 'Add habits to start tracking your routine';
    } else if (completedCount == totalCount) {
      title = 'All Done For Today! 🎉';
      subtitle = 'Amazing job! You completed all scheduled habits.';
    } else if (completedCount == 0) {
      title = 'Start Your Day Strong';
      subtitle = '0 of $totalCount completed. Take the first step!';
    } else {
      title = 'Great Progress! 💪';
      subtitle = '$completedCount of $totalCount habits done today ($percentage%)';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Daily Goal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
