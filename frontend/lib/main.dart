import 'package:flutter/material.dart';

import 'data/api_student_exam_repository.dart';
import 'data/student_exam_repository.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(ToeicReadingApp(repository: ApiStudentExamRepository()));
}

class ToeicReadingApp extends StatelessWidget {
  const ToeicReadingApp({super.key, required this.repository});

  final StudentExamRepository repository;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF142B4A);
    const teal = Color(0xFF1AA89A);

    return MaterialApp(
      title: 'Readwise',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE9EEF3),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: navy,
          secondary: teal,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8FC),
          foregroundColor: navy,
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
