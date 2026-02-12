/// Represents a user activity that can be tracked offline and synced later
class ActivityRecord {
  final String id;
  final String userId;
  final String meditationId;
  final DateTime timestamp;
  final int durationSeconds;
  final bool completed;
  final bool synced;

  const ActivityRecord({
    required this.id,
    required this.userId,
    required this.meditationId,
    required this.timestamp,
    required this.durationSeconds,
    required this.completed,
    this.synced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'meditation_id': meditationId,
      'timestamp': timestamp.toIso8601String(),
      'duration_seconds': durationSeconds,
      'completed': completed,
      'synced': synced,
    };
  }

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      meditationId: json['meditation_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationSeconds: json['duration_seconds'] as int,
      completed: json['completed'] as bool,
      synced: json['synced'] as bool? ?? false,
    );
  }

  ActivityRecord copyWith({
    String? id,
    String? userId,
    String? meditationId,
    DateTime? timestamp,
    int? durationSeconds,
    bool? completed,
    bool? synced,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      meditationId: meditationId ?? this.meditationId,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() {
    return 'ActivityRecord(id: $id, meditation: $meditationId, duration: ${durationSeconds}s, synced: $synced)';
  }
}
