/// Micro-ritual data model for Daily MicroRituals app
class Ritual {
  final String id;
  final String name;
  final String emoji;
  final bool isCompleted;
  final int streak;
  final DateTime? lastCompleted;

  const Ritual({
    required this.id,
    required this.name,
    required this.emoji,
    this.isCompleted = false,
    this.streak = 0,
    this.lastCompleted,
  });

  Ritual copyWith({
    String? id,
    String? name,
    String? emoji,
    bool? isCompleted,
    int? streak,
    DateTime? lastCompleted,
  }) {
    return Ritual(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      isCompleted: isCompleted ?? this.isCompleted,
      streak: streak ?? this.streak,
      lastCompleted: lastCompleted ?? this.lastCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'isCompleted': isCompleted,
      'streak': streak,
      'lastCompleted': lastCompleted?.toIso8601String(),
    };
  }

  factory Ritual.fromJson(Map<String, dynamic> json) {
    return Ritual(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      streak: json['streak'] as int? ?? 0,
      lastCompleted: json['lastCompleted'] != null
          ? DateTime.parse(json['lastCompleted'] as String)
          : null,
    );
  }
}
