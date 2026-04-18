import 'dart:async';
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:sarak/main.dart'; // 메인 파일 불러오기

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // ⏰ 3초 기다렸다가 진짜 메인 화면(MainShell)으로 넘어갑니다!
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        // 메인 진입 직전에 UpgradeAlert로 감싸서 앱스토어에 새 버전이 올라와 있으면
        // "업데이트하기 / 나중에" 모달이 뜨도록 함.
        MaterialPageRoute(
          builder: (context) => UpgradeAlert(
            upgrader: Upgrader(
              languageCode: 'ko',
              countryCode: 'KR',
              durationUntilAlertAgain: const Duration(days: 1),
              messages: _SarakUpgraderMessages(),
            ),
            showIgnore: false,
            showReleaseNotes: true,
            child: const MainShell(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4B2C71), // 🎨 보라색 배경
      body: Center(
        child: Image.asset(
          'assets/intro.png',
          // 🌟 이미지가 화면에 빈틈없이 꽉 차도록 설정했습니다.
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

/// 한국어 모달 문구 커스터마이즈.
/// 기본 한국어 번역 대신 앱 톤에 맞는 표현으로 교체.
class _SarakUpgraderMessages extends UpgraderMessages {
  _SarakUpgraderMessages() : super(code: 'ko');

  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.title:
        return '새로운 버전이 나왔어요';
      case UpgraderMessage.prompt:
        return '사락에 새 기능과 개선 사항이 추가되었습니다. 지금 업데이트하시겠습니까?';
      case UpgraderMessage.body:
        return '{{appName}} {{currentAppStoreVersion}} 버전을 사용할 수 있습니다. (현재 {{currentInstalledVersion}})';
      case UpgraderMessage.buttonTitleUpdate:
        return '업데이트';
      case UpgraderMessage.buttonTitleLater:
        return '나중에';
      case UpgraderMessage.buttonTitleIgnore:
        return '무시';
      case UpgraderMessage.releaseNotes:
        return '업데이트 내용';
      default:
        return super.message(messageKey);
    }
  }
}