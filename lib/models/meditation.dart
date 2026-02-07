/// Meditation content model for the 'meditations' collection
class Meditation {
  final String id;
  final String title;
  final int duration; // in minutes
  final int? durationSeconds; // precise duration
  final String category; // Sleep, Focus, Anxiety, etc.
  final String audioUrl;
  final String coverImage;
  final bool isPremium;
  final bool isAdRequired;

  const Meditation({
    required this.id,
    required this.title,
    required this.duration,
    required this.category,
    required this.audioUrl,
    required this.coverImage,
    this.isPremium = false,
    this.isAdRequired = false,
    this.durationSeconds,
  });

  /// Create from Firestore document
  factory Meditation.fromJson(Map<String, dynamic> json, String docId) {
    return Meditation(
      id: docId,
      title: json['title'] as String? ?? '',
      duration: json['duration'] as int? ?? 5,
      category: json['category'] as String? ?? 'Focus',
      audioUrl: json['audio_url'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      isAdRequired: json['is_ad_required'] as bool? ?? false,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'duration': duration,
      'category': category,
      'audio_url': audioUrl,
      'cover_image': coverImage,
      'is_premium': isPremium,
      'is_ad_required': isAdRequired,
      'duration_seconds': durationSeconds,
    };
  }

  /// Available categories
  static const List<String> categories = [
    'Sleep',
    'Focus',
    'Anxiety',
    'Stress',
    'Morning',
    'Evening',
    'Breathing',
  ];

  /// Create a copy with updated fields
  Meditation copyWith({
    String? id,
    String? title,
    int? duration,
    String? category,
    String? audioUrl,
    String? coverImage,
    bool? isPremium,
    bool? isAdRequired,
    int? durationSeconds,
  }) {
    return Meditation(
      id: id ?? this.id,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      audioUrl: audioUrl ?? this.audioUrl,
      coverImage: coverImage ?? this.coverImage,
      isPremium: isPremium ?? this.isPremium,
      isAdRequired: isAdRequired ?? this.isAdRequired,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  /// Get formatted duration string
  String get formattedDuration {
    if (durationSeconds != null) {
      final minutes = durationSeconds! ~/ 60;
      final seconds = durationSeconds! % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$duration min';
  }
}
