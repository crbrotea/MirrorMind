import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/repositories/gallery_repository.dart';
import '../../domain/models/gallery_entry.dart';

/// Fetches the gallery entries for a given user ID.
///
/// Uses [FutureProvider.family] so the result is cached per user and
/// automatically provides loading / error / data states via [AsyncValue].
final galleryProvider =
    FutureProvider.family<List<GalleryEntry>, String>((ref, userId) async {
  final repository = GalleryRepository(apiBaseUrl);
  return repository.getGallery(userId);
});
