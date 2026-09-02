import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'providers/notes_provider.dart';
import 'providers/tasks_provider.dart';
import 'providers/settings_provider.dart';
import 'services/task_engine.dart';
import 'services/reminder_scheduler.dart';
import 'services/android_reminder_scheduler.dart';
import 'services/widget_data_adapter.dart';
import 'services/deep_link_coordinator.dart';
import 'themes/quick_notes_theme.dart';
import 'views/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable runtime fetching so missing fonts like PlusJakartaSans and Outfit can load
  GoogleFonts.config.allowRuntimeFetching = true;

  // Initialize Home Screen Widget Platform Bridge & Deep-Link Listeners
  WidgetDataAdapter.instance.initializeAppGroup();
  DeepLinkCoordinator.instance.initialize();

  // Set preferred orientations and system styling overlays
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Pre-initialize SettingsProvider so correct theme mode is active immediately on launch
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  final ReminderScheduler scheduler =
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? AndroidReminderScheduler()
          : LoggingReminderScheduler();

  final taskEngine = TaskEngine(scheduler: scheduler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDarkMode = settingsProvider.isDarkMode;

    return MaterialApp(
      title: 'QuickNotes',
      debugShowCheckedModeBanner: false,

      // Light Theme configuration
      theme: QuickNotesTheme.lightTheme,

      // Dark Theme configuration
      darkTheme: QuickNotesTheme.darkTheme,

      // Centralized Reactive ThemeMode
      themeMode: settingsProvider.themeMode,

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
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF333333).withValues(alpha: 0.15),
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
