import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/theme.dart';

/// Root widget for the MirrorMind application.
class MirrorMindApp extends StatelessWidget {
  const MirrorMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MirrorMind',
      debugShowCheckedModeBanner: false,
      theme: mirrorMindTheme,
      routerConfig: router,
    );
  }
}
