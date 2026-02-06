/// Ritual category enum for Daily MicroRituals
enum RitualCategory {
  breath,
  stretch,
  focus;

  String get displayName {
    switch (this) {
      case RitualCategory.breath:
        return 'Breath';
      case RitualCategory.stretch:
        return 'Stretch';
      case RitualCategory.focus:
        return 'Focus';
    }
  }

  String get emoji {
    switch (this) {
      case RitualCategory.breath:
        return '🌬️';
      case RitualCategory.stretch:
        return '🧘';
      case RitualCategory.focus:
        return '🧠';
    }
  }

  static RitualCategory fromString(String value) {
    return RitualCategory.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RitualCategory.focus,
    );
  }
}

/// Firestore ritual model
/// Collection: 'rituals'
class FirestoreRitual {
  final String id;
  final String title;
  final RitualCategory category;
  final int durationSeconds;
  final List<String> instructions;
  final String audioUrl;
  final String? coverImageUrl;
  final bool isPremium;

  const FirestoreRitual({
    required this.id,
    required this.title,
    required this.category,
    required this.durationSeconds,
    required this.instructions,
    required this.audioUrl,
    this.coverImageUrl,
    this.isPremium = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category.name,
      'duration_seconds': durationSeconds,
      'instructions': instructions,
      'audio_url': audioUrl,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      'is_premium': isPremium,
    };
  }

  factory FirestoreRitual.fromJson(Map<String, dynamic> json) {
    return FirestoreRitual(
      id: json['id'] as String,
      title: json['title'] as String,
      category: RitualCategory.fromString(json['category'] as String),
      durationSeconds: json['duration_seconds'] as int,
      instructions: List<String>.from(json['instructions'] as List),
      audioUrl: json['audio_url'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  FirestoreRitual copyWith({
    String? id,
    String? title,
    RitualCategory? category,
    int? durationSeconds,
    List<String>? instructions,
    String? audioUrl,
    String? coverImageUrl,
    bool? isPremium,
  }) {
    return FirestoreRitual(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      instructions: instructions ?? this.instructions,
      audioUrl: audioUrl ?? this.audioUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
