import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import './services/auth_service.dart';
import './services/download_service.dart';
import './services/audio_service.dart';
import './services/audio_handler.dart';
import './services/playlist_service.dart';
import './services/language_service.dart';
import './screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageService = LanguageService();
  await languageService.init();

  // Initialise background audio handler BEFORE runApp.
  // This registers the app with the OS audio system so audio keeps playing
  // when the screen is locked or the app goes to background.
  final audioHandler = await initAudioHandler();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => languageService),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DownloadService()),
        // Pass the handler so AudioService uses the same just_audio player
        // that is already registered with the OS background service.
        ChangeNotifierProvider(create: (_) => AudioService(audioHandler)),
        ChangeNotifierProvider(create: (_) => PlaylistService()),
      ],
      child: const ThayTubeApp(),
    ),
  );
}


class ThayTubeApp extends StatelessWidget {
  const ThayTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final String? primaryFamily = GoogleFonts.beVietnamPro().fontFamily;
    final List<String> fallbackFamilies = [
      GoogleFonts.notoSansThai().fontFamily!,
      GoogleFonts.notoSansLao().fontFamily!,
    ];

    TextStyle applyCustomFonts(TextStyle? style) {
      if (style == null) return const TextStyle();
      return style.copyWith(
        fontFamily: primaryFamily,
        fontFamilyFallback: fallbackFamilies,
      );
    }

    final baseTextTheme = GoogleFonts.beVietnamProTextTheme(
      const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: Colors.white70),
        bodyMedium: TextStyle(color: Colors.white60),
      ),
    );

    final customTextTheme = TextTheme(
      displayLarge: applyCustomFonts(baseTextTheme.displayLarge),
      displayMedium: applyCustomFonts(baseTextTheme.displayMedium),
      displaySmall: applyCustomFonts(baseTextTheme.displaySmall),
      headlineLarge: applyCustomFonts(baseTextTheme.headlineLarge),
      headlineMedium: applyCustomFonts(baseTextTheme.headlineMedium),
      headlineSmall: applyCustomFonts(baseTextTheme.headlineSmall),
      titleLarge: applyCustomFonts(baseTextTheme.titleLarge),
      titleMedium: applyCustomFonts(baseTextTheme.titleMedium),
      titleSmall: applyCustomFonts(baseTextTheme.titleSmall),
      bodyLarge: applyCustomFonts(baseTextTheme.bodyLarge),
      bodyMedium: applyCustomFonts(baseTextTheme.bodyMedium),
      bodySmall: applyCustomFonts(baseTextTheme.bodySmall),
      labelLarge: applyCustomFonts(baseTextTheme.labelLarge),
      labelMedium: applyCustomFonts(baseTextTheme.labelMedium),
      labelSmall: applyCustomFonts(baseTextTheme.labelSmall),
    );

    return MaterialApp(
      title: 'ThayTube Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        fontFamily: primaryFamily,
        fontFamilyFallback: fallbackFamilies,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2A5F),
          secondary: Color(0xFFFF7E40),
          surface: Color(0xFF161622),
          background: Color(0xFF0F0F1A),
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F1A),
          selectedItemColor: Color(0xFFFF2A5F),
          unselectedItemColor: Colors.white38,
        ),
        textTheme: customTextTheme,
      ),
      home: const MainNavigationScreen(),
    );
  }
}
