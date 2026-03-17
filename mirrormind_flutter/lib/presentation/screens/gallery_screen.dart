import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/services/user_id_service.dart';
import '../../domain/models/gallery_entry.dart';
import '../providers/gallery_provider.dart';

/// Displays a grid of past session thumbnails fetched from the backend.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final id = await UserIdService.getUserId();
    if (mounted) {
      setState(() => _userId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text('Galeria'),
      ),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _GalleryBody(userId: _userId!),
    );
  }
}

/// Watches the [galleryProvider] and renders the appropriate UI for loading,
/// error, empty, and data states.
class _GalleryBody extends ConsumerWidget {
  const _GalleryBody({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(galleryProvider(userId));

    return asyncEntries.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Error al cargar la galeria:\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aun no hay sesiones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus paisajes emocionales apareceran aqui',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3 / 4,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _GalleryCard(
              entry: entry,
              onTap: () => _showFullScreenImage(context, entry),
            );
          },
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, GalleryEntry entry) {
    final imageUrl = entry.finalImageUrl;
    if (imageUrl == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _FullScreenViewer(
        imageUrl: imageUrl,
        emotion: entry.finalEmotion,
      ),
    );
  }
}

/// A single gallery card showing a thumbnail, emotion label, and date.
class _GalleryCard extends StatelessWidget {
  const _GalleryCard({required this.entry, required this.onTap});

  final GalleryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = emotionColors[entry.finalEmotion] ?? emotionColors['neutral']!;
    final emotionLabel =
        emotionDisplayNames[entry.finalEmotion] ?? entry.finalEmotion;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary, colors.secondary],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image if available.
            if (entry.thumbnailUrl != null)
              Image.network(
                entry.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),

            // Bottom gradient overlay with metadata.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emotionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.date,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen image viewer shown as a dialog.
class _FullScreenViewer extends StatelessWidget {
  const _FullScreenViewer({
    required this.imageUrl,
    required this.emotion,
  });

  final String imageUrl;
  final String emotion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Centered image.
          Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image,
                color: Colors.white24,
                size: 64,
              ),
            ),
          ),

          // Close button.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
