// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'gate/auth_gate.dart';

// base pages
import 'pages/landing_page.dart';
import 'pages/profile_setup_page.dart';
import 'pages/home_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/admin_dashboard_page.dart';

// rounds
import 'pages/round1_page.dart';
import 'pages/round2_page.dart';
import 'pages/round3_page.dart';
import 'pages/round4_page.dart';
import 'pages/round5_page.dart'; // Surveillance Hack (YouTube with desktop fallback)
import 'pages/round6_page.dart'; // Vault master code

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0C1016),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE53935),
        secondary: Color(0xFFFFD54A),
        surface: Color(0xFF121722),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayMedium: GoogleFonts.orbitron(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: const Color(0xFFE6EEF5),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFFFFD54A),
        selectionColor: Color(0x33FFD54A),
        selectionHandleColor: Color(0xFFFFD54A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD54A), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        labelStyle: const TextStyle(color: Color(0xFFE6EEF5)),
        floatingLabelStyle: const TextStyle(color: Color(0xFFFFD54A)),
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD54A),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFD54A),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E232B),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Heist',
      theme: theme,
      home: const AuthGate(),

      // Canonical routes (match HomePage navigation: '/round1'..'/round6')
      routes: {
        // base
        '/landing': (_) => const LandingPage(),
        '/setup': (_) => const ProfileSetupPage(),
        '/home': (_) => const HomePage(),
        '/leaderboard': (_) => const LeaderboardPage(),
        '/admin': (_) => const AdminDashboardPage(),

        // rounds
        '/round1': (_) => const Round1Page(),
        '/round2': (_) => const Round2Page(),
        '/round3': (_) => const Round3Page(),
        '/round4': (_) => const Round4Page(),
        '/round5': (_) => const Round5Page(),
        '/round6': (_) => const Round6Page(),
      },

      // Back-compat: remap old '/round/1'… style if anything still pushes it.
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/round/')) {
          final n = int.tryParse(name.split('/').last);
          if (n != null && n >= 1 && n <= 6) {
            final page = <int, Widget>{
              1: const Round1Page(),
              2: const Round2Page(),
              3: const Round3Page(),
              4: const Round4Page(),
              5: const Round5Page(),
              6: const Round6Page(),
            }[n]!;
            // Use canonical name '/round$n'
            return MaterialPageRoute(
              builder: (_) => page,
              settings: RouteSettings(name: '/round$n'),
            );
          }
        }
        return null; // fall back to default unknown route handling
      },
    );
  }
}
