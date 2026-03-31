import 'dart:async';
import 'package:flutter/material.dart';
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
      Navigator.pushReplacement(
        context,
        // 🌟 에러 해결! MyHomePage를 목사님의 화면인 MainShell로 바꿨습니다.
        MaterialPageRoute(builder: (context) => const MainShell()), 
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