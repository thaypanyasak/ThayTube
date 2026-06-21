class Playlist {
  final String id;
  final String name;
  final String description;
  final List<String> trackIds; // List of video IDs in the playlist
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.trackIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trackIds': trackIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      trackIds: List<String>.from(map['trackIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
