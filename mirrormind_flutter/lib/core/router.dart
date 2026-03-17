import 'package:go_router/go_router.dart';

import '../presentation/screens/home_screen.dart';
import '../presentation/screens/session_screen.dart';
import '../presentation/screens/gallery_screen.dart';

/// The top-level router configuration for the MirrorMind app.
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/session',
      builder: (context, state) => const SessionScreen(),
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => const GalleryScreen(),
    ),
  ],
);
