import 'splash_page.dart'; // 🌟 인트로 페이지 불러오기
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/database/local_storage.dart';
import 'core/providers/auth_provider.dart';
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

class SarakApp extends StatelessWidget {
  const SarakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '사락사락 Bible', // 🌟 앱 이름 반영
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // 🌟 이제 앱을 켜면 MainShell이 아니라 SplashPage가 먼저 뜹니다!
      home: const SplashPage(), 
    );
  }
}

// -------------------------------------------------------------------------
// 아래는 메인 화면(껍데기) 코드입니다. 
// SplashPage에서 3초 뒤에 이 MainShell로 넘어오게 됩니다.
// -------------------------------------------------------------------------

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => MainShellState();
}

class MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<CalendarScreenState> _calendarKey =
      GlobalKey<CalendarScreenState>();

  void switchTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      _calendarKey.currentState?.loadData();
    }
  }

  Future<void> _onTabTapped(int index) async {
    if (index == 2) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('로그인이 필요해요'),
            content: const Text('그룹 통독은 Google 계정으로 로그인해야 사용할 수 있어요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('로그인'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await ref.read(authServiceProvider).signInWithGoogle();
            if (mounted) setState(() => _currentIndex = 2);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('로그인 실패: $e')),
              );
            }
          }
        }
        return;
      }
    }
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
        onTap: _onTabTapped,
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