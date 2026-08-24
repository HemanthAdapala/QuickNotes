import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'providers/notes_provider.dart';
import 'providers/tasks_provider.dart';
import 'services/task_engine.dart';
import 'services/reminder_scheduler.dart';
import 'services/android_reminder_scheduler.dart';
import 'views/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Disable runtime fetching of Google Fonts to prevent crashes when offline
  GoogleFonts.config.allowRuntimeFetching = false;

  // Set preferred orientations and system styling overlays
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final ReminderScheduler scheduler =
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? AndroidReminderScheduler()
          : LoggingReminderScheduler();

  final taskEngine = TaskEngine(scheduler: scheduler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(
            create: (_) => TasksProvider(engine: taskEngine)),
      ],
      child: const QuickNotesApp(),
    ),
  );
}

class QuickNotesApp extends StatelessWidget {
  const QuickNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final isDarkMode = notesProvider.isDarkMode;

    // Generate harmonious QuickNotes Playful Light ColorScheme
    const lightColorScheme = ColorScheme.light(
      primary: Color(0xFF6366F1), // Electric Indigo
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF14B8A6), // Neon Teal
      onSecondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFFF97316), // Playful Orange
      surface: Color(0xFFF5F3EF), // Playful Warm Surface
      onSurface: Color(0xFF1E1B4B), // Midnight Navy
      outline: Color(0xFF1E1B4B),
      outlineVariant: Color(0xFFE2E8F0),
    );

    // Generate harmonious QuickNotes Playful Dark ColorScheme
    const darkColorScheme = ColorScheme.dark(
      primary: Color(0xFF818CF8), // Light Indigo
      onPrimary: Color(0xFF0B0D17),
      secondary: Color(0xFF2DD4BF), // Light Teal
      onSecondary: Color(0xFF0B0D17),
      tertiary: Color(0xFFFB923C), // Light Orange
      surface: Color(0xFF1E1C2E), // Playful Deep Surface
      onSurface: Color(0xFFFAF8F5), // Light Cream Text
      outline: Color(0xFFFAF8F5),
      outlineVariant: Color(0xFF312E81),
    );

    final lightBaseTextTheme = ThemeData.light().textTheme;
    final darkBaseTextTheme = ThemeData.dark().textTheme;

    return MaterialApp(
      title: 'QuickNotes',
      debugShowCheckedModeBanner: false,

      // Light Theme configuration
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFFDF9), // Warm Cream Paper
        cardColor: const Color(0xFFFDFBF7), // Soft Card Base
        dividerColor: const Color(0xFF1E1B4B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFDF9),
          foregroundColor: Color(0xFF1E1B4B),
          elevation: 0,
        ),
        textTheme: GoogleFonts.interTextTheme(
          lightBaseTextTheme.copyWith(
            displayLarge: GoogleFonts.inter(
                fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
            displayMedium: GoogleFonts.inter(
                fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
            displaySmall: GoogleFonts.inter(
                fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
            headlineLarge: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
            headlineMedium: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
            headlineSmall: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
            titleLarge: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
            titleMedium: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
            titleSmall: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6366F1),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF333333),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),

      // Dark Theme configuration
      themeMode: ThemeMode.light,

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF0B0D17), // Obsidian Night
        cardColor: const Color(0xFF1A1C2E),
        dividerColor: const Color(0xFF312E81),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0D17),
          foregroundColor: Color(0xFFFAF8F5),
          elevation: 0,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          darkBaseTextTheme.copyWith(
            displayLarge: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: const Color(0xFFFAF8F5)),
            displayMedium: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: const Color(0xFFFAF8F5)),
            displaySmall: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: const Color(0xFFFAF8F5)),
            headlineLarge: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
            headlineMedium: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
            headlineSmall: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
            titleLarge: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
            titleMedium: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
            titleSmall: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF818CF8),
          foregroundColor: Color(0xFF0B0D17),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF333333),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),

      home: const SplashScreen(),
      builder: (context, child) {
        if (!kIsWeb) return child!;
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return child!;
            }
            return Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              body: Center(
                child: Container(
                  width: 402,
                  height: 874,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF0B0D17)
                        : const Color(0xFFFFFDF9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF312E81)
                          : const Color(0xFFE2E8F0),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: child!,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
