import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mirrormind_flutter/domain/models/gallery_entry.dart';

/// Repository for fetching gallery data from the MirrorMind REST API.
///
/// Each user has a gallery of past session artifacts (images + emotion data)
/// that can be browsed after sessions are complete.
class GalleryRepository {
  final String _baseUrl;

  /// Creates a gallery repository targeting the given [baseUrl].
  ///
  /// The [baseUrl] should not end with a trailing slash (e.g.
  /// `http://localhost:8080`).
  GalleryRepository(this._baseUrl);

  /// Fetches all gallery entries for the given [userId].
  ///
  /// Returns an empty list if the request fails or the user has no entries.
  Future<List<GalleryEntry>> getGallery(String userId) async {
    final uri = Uri.parse('$_baseUrl/api/gallery/$userId');

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return [];
      }

      final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
      return body
          .map((item) => GalleryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches the full detail of a specific gallery session.
  ///
  /// Returns `null` if the request fails or the entry does not exist.
  Future<Map<String, dynamic>?> getSessionDetail(
    String userId,
    String galleryId,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/gallery/$userId/$galleryId');

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
