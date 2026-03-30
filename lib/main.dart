import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/database/local_storage.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/group/screens/group_screen.dart';
import 'features/settings/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: SarakApp()));
}

class SarakApp extends ConsumerWidget {
  const SarakApp({super.key});

  Widget _buildHome(AsyncValue<User?> authState) {
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = authState.valueOrNull;
    if (user != null) return const MainShell();
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: '사락',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: _buildHome(authState),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<CalendarScreenState> _calendarKey =
      GlobalKey<CalendarScreenState>();

  void switchTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      _calendarKey.currentState?.loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onTabSwitch: switchTab),
      CalendarScreen(key: _calendarKey),
      const GroupScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            _calendarKey.currentState?.loadData();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: '달력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: '그룹',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: '더보기',
          ),
        ],
      ),
    );
  }
}
