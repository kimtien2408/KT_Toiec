import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/data/sample_exam.dart';
import 'package:frontend/data/student_exam_repository.dart';
import 'package:frontend/models/exam.dart';

void main() {
  testWidgets('student app stays phone-width on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ToeicReadingApp(repository: _SampleExamRepository()),
    );
    await tester.pumpAndSettle();

    final appSize = tester.getSize(find.byType(Scaffold).first);
    final appCenter = tester.getCenter(find.byType(Scaffold).first);
    expect(appSize.width, 480);
    expect(appCenter.dx, 720);
  });

  test('shuffled exam preserves every question and the source exam', () {
    final shuffledExam = sampleExam.withShuffledQuestions(random: Random(7));
    final shuffledPrompts = shuffledExam.questions
        .map((question) => question.prompt)
        .toList();
    final originalPrompts = sampleExam.questions
        .map((question) => question.prompt)
        .toList();

    expect(
      shuffledExam.questions.map((question) => question.id ?? question.prompt),
      unorderedEquals(
        sampleExam.questions.map((question) => question.id ?? question.prompt),
      ),
    );
    expect(shuffledPrompts, isNot(equals(originalPrompts)));
    expect(
      sampleExam.questions.first.prompt,
      'All employees must submit _____ travel receipts by Friday.',
    );
  });

  test(
    'shuffled exam changes order when a random shuffle leaves it unchanged',
    () {
      final shuffledExam = sampleExam.withShuffledQuestions(
        random: _NoOpRandom(),
      );

      expect(
        shuffledExam.questions.map((question) => question.prompt).toList(),
        isNot(
          equals(
            sampleExam.questions.map((question) => question.prompt).toList(),
          ),
        ),
      );
    },
  );

  testWidgets('student can answer and submit a practice exam', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _SampleExamRepository();
    await tester.pumpWidget(ToeicReadingApp(repository: repository));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Home layout');

    expect(find.text('Readwise'), findsOneWidget);
    expect(find.text('Đề thi của bạn'), findsOneWidget);
    expect(repository.examListRequestCount, 1);
    await tester.tap(find.byTooltip('Làm mới danh sách đề thi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Refreshing home');
    expect(repository.examListRequestCount, 2);

    await tester.tap(find.text('Ca chiều'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Filtering home');

    final startButton = find.text('Bắt đầu làm bài');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Confirmation screen');

    expect(find.text('Quy chế thi'), findsOneWidget);
    expect(find.text('CA CHIỀU'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vào thi ·'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Exam screen');
    expect(repository.lastValidatedSessionId, 'afternoon-session');

    final firstQuestion = sampleExam.questions.firstWhere(
      (question) => find.text(question.prompt).evaluate().isNotEmpty,
    );

    final correctAnswer = find.text(
      firstQuestion.choices[firstQuestion.correctIndex!],
    );
    await tester.ensureVisible(correctAnswer);
    await tester.tap(correctAnswer);
    await tester.pumpAndSettle();

    expect(find.text(firstQuestion.prompt), findsNothing);
    expect(
      sampleExam.questions
          .where((question) => question.prompt != firstQuestion.prompt)
          .any((question) => find.text(question.prompt).evaluate().isNotEmpty),
      isTrue,
    );

    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Result screen');

    expect(find.text('10%'), findsOneWidget);
    expect(find.text('1 / 10 câu đúng'), findsOneWidget);
    expect(repository.lastSubmittedSessionId, 'afternoon-session');

    final reviewButton = find.text('Xem lại đáp án & gợi ý');
    await tester.scrollUntilVisible(
      reviewButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    expect(find.text('Xem lại đáp án'), findsOneWidget);
    final submittedQuestions = repository.lastSubmittedExam!.questions;
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('Câu ${submittedQuestions[1].number}'), findsOneWidget);
    await tester.tap(find.text('Câu tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Câu ${submittedQuestions[2].number}'), findsOneWidget);
  });
}

class _SampleExamRepository implements StudentExamRepository {
  String? lastValidatedSessionId;
  String? lastSubmittedSessionId;
  Exam? lastSubmittedExam;
  int examListRequestCount = 0;

  @override
  Future<List<ExamSummary>> getPublishedExams() async {
    examListRequestCount++;
    return [
      ExamSummary(
        id: sampleExam.id,
        title: sampleExam.title,
        duration: sampleExam.duration,
        questionCount: sampleExam.questions.length,
        sessions: [
          ExamSession(
            id: 'morning-session',
            shift: 'Morning',
            requiresSessionCode: false,
          ),
          ExamSession(
            id: 'afternoon-session',
            shift: 'Afternoon',
            sessionDate: DateTime(2026, 10, 20),
            sessionStart: '13:00',
            sessionEnd: '14:15',
            requiresSessionCode: false,
          ),
        ],
      ),
    ];
  }

  @override
  Future<Exam> getExam(String id) async => sampleExam;

  @override
  Future<void> validateSessionCode(
    String examId,
    String sessionId,
    String? code,
  ) async {
    lastValidatedSessionId = sessionId;
  }

  @override
  Future<ExamSubmissionResult> submitExam(
    Exam exam,
    String sessionId,
    List<int?> answers,
    String? sessionCode,
  ) async {
    lastSubmittedSessionId = sessionId;
    lastSubmittedExam = exam;
    final reviews = exam.questions
        .asMap()
        .entries
        .map((entry) {
          final selectedIndex = answers[entry.key];
          final question = entry.value;
          return ExamAnswerReview(
            selectedIndex: selectedIndex,
            correctIndex: question.correctIndex!,
            hint: question.hint,
          );
        })
        .toList(growable: false);
    final correct = reviews
        .where((review) => review.selectedIndex == review.correctIndex)
        .length;
    final unanswered = reviews
        .where((review) => review.selectedIndex == null)
        .length;
    return ExamSubmissionResult(
      totalQuestions: reviews.length,
      correct: correct,
      incorrect: reviews.length - correct - unanswered,
      unanswered: unanswered,
      answers: reviews,
    );
  }
}

class _NoOpRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}
