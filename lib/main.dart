import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/ai_suggestions_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/active_session_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'providers.dart';
import 'services/auth_service.dart';
import 'services/subscription_service.dart';
import 'package:confetti/confetti.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: GymProgressApp()));
}

class GymProgressApp extends StatefulWidget {
  const GymProgressApp({super.key});

  @override
  State<GymProgressApp> createState() => _GymProgressAppState();
}

class _GymProgressAppState extends State<GymProgressApp> {
  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _subscriptionService.initialize();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return MaterialApp(
      title: 'Gym Progress AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA6),
          brightness: Brightness.dark,
          surface: const Color(0xFF121218),
          primary: const Color(0xFF00BFA6),
          secondary: const Color(0xFF7C4DFF),
          tertiary: const Color(0xFF00E5FF),
        ),
        scaffoldBackgroundColor: const Color(0xFF121218),
        textTheme: baseTextTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF00BFA6),
              width: 1.5,
            ),
          ),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFA6),
            foregroundColor: const Color(0xFF121218),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00BFA6),
            side: const BorderSide(color: Color(0xFF00BFA6)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00E5FF),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _authService,
        builder: (context, _) {
          if (!_authService.isSignedIn) {
            return AuthWrapper(
              authService: _authService,
            );
          }
          return HomeShell(
            authService: _authService,
            subscriptionService: _subscriptionService,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final AuthService authService;

  const AuthWrapper({super.key, required this.authService});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSignIn = true;

  @override
  Widget build(BuildContext context) {
    if (_showSignIn) {
      return SignInScreen(
        authService: widget.authService,
        onSignUpPressed: () => setState(() => _showSignIn = false),
      );
    }
    return SignUpScreen(
      authService: widget.authService,
      onSignInPressed: () => setState(() => _showSignIn = true),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  final AuthService authService;
  final SubscriptionService subscriptionService;

  const HomeShell({
    super.key,
    required this.authService,
    required this.subscriptionService,
  });

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    // Login to RevenueCat with user ID
    final user = widget.authService.firebaseUser;
    if (user != null) {
      widget.subscriptionService.loginUser(user.uid);
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Widget _buildActiveIcon(BuildContext context, bool hasActiveSession) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.fitness_center_rounded),
        if (hasActiveSession)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1A1A24), width: 1.2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryIcon(BuildContext context, int unseenCount) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.history_rounded),
        if (unseenCount > 0)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1A1A24), width: 1.2),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch confetti trigger and play animation when it changes
    ref.listen<int>(confettiTriggerProvider, (previous, next) {
      if (previous != null && next > previous) {
        _confettiController.play();
      }
    });

    // Watch active session and unseen history count
    final activeSessionAsync = ref.watch(activeSessionProvider);
    final unseenCountAsync = ref.watch(unseenHistoryCountProvider);
    final store = ref.read(storeProvider);

    final activeSession = activeSessionAsync.valueOrNull;
    final hasActiveSession = activeSession != null;
    final unseenHistoryCount = unseenCountAsync.valueOrNull ?? 0;

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          IndexedStack(
            index: _index,
            children: [
              const DashboardScreen(),
              activeSession != null
                  ? ActiveSessionScreen(
                      session: activeSession,
                      onCleared: () => ref.invalidate(activeSessionProvider),
                    )
                  : _NoActiveSession(
                      onPlanPressed: () => setState(() => _index = 3),
                    ),
              const HistoryScreen(),
              const AiSuggestionsScreen(),
              SettingsScreen(
                authService: widget.authService,
                subscriptionService: widget.subscriptionService,
              ),
            ],
          ),
          // Celebration!
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Color(0xFF00BFA6),
              ],
              minBlastForce: 12,
              maxBlastForce: 30,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (value) async {
            if (value == 2 && unseenHistoryCount > 0) {
              // Mark history as seen when user taps History tab
              await store.markHistoryAsSeen();
              ref.invalidate(unseenHistoryCountProvider);
            }
            setState(() => _index = value);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.white.withValues(alpha: 0.4),
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: _buildActiveIcon(context, hasActiveSession),
              label: 'Active',
            ),
            BottomNavigationBarItem(
              icon: _buildHistoryIcon(context, unseenHistoryCount),
              label: 'History',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_rounded),
              label: 'AI',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _NoActiveSession extends StatelessWidget {
  final VoidCallback onPlanPressed;

  const _NoActiveSession({required this.onPlanPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No active session',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Generate a plan with AI to start your workout tracker.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onPlanPressed,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Go to AI Planner'),
            ),
          ],
        ),
      ),
    );
  }
}
