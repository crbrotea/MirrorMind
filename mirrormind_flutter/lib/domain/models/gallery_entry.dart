/// Represents a single gallery entry summarizing a completed session.
class GalleryEntry {
  final String sessionId;
  final String finalEmotion;
  final String date;
  final String? thumbnailUrl;
  final String? finalImageUrl;
  final List<String> emotions;
  final double durationSeconds;

  const GalleryEntry({
    required this.sessionId,
    required this.finalEmotion,
    required this.date,
    this.thumbnailUrl,
    this.finalImageUrl,
    required this.emotions,
    required this.durationSeconds,
  });

  /// Creates a [GalleryEntry] from a JSON map.
  factory GalleryEntry.fromJson(Map<String, dynamic> json) {
    return GalleryEntry(
      sessionId: json['session_id'] as String,
      finalEmotion: json['final_emotion'] as String,
      date: json['date'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      finalImageUrl: json['final_image_url'] as String?,
      emotions: (json['emotions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      durationSeconds: (json['duration_seconds'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'final_emotion': finalEmotion,
        'date': date,
        'thumbnail_url': thumbnailUrl,
        'final_image_url': finalImageUrl,
        'emotions': emotions,
        'duration_seconds': durationSeconds,
      };
}
