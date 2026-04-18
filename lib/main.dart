import 'splash_page.dart'; // 🌟 인트로 페이지 불러오기
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/database/local_storage.dart';
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
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  void switchTab(int index) {
    setState(() => _currentIndex = index);
    _onTabShown(index);
  }

  Future<void> _onTabTapped(int index) async {
    setState(() => _currentIndex = index);
    _onTabShown(index);
  }

  void _onTabShown(int index) {
    // 홈/달력은 IndexedStack에 보관되어 initState가 다시 돌지 않으므로
    // 해당 탭이 보여질 때마다 state.loadData()로 강제 갱신한다.
    if (index == 0) {
      _homeKey.currentState?.loadData();
    } else if (index == 1) {
      _calendarKey.currentState?.loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(key: _homeKey, onTabSwitch: switchTab),
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