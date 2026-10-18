import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/api_student_exam_repository.dart';
import 'package:frontend/models/exam.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'exam detail does not contain the correct answer before submission',
    () async {
      final repository = ApiStudentExamRepository(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/exams/exam-id');
          return http.Response(
            jsonEncode({
              'id': 'exam-id',
              'title': 'Đề TOEIC',
              'durationMinutes': 75,
              'questions': [
                {
                  'id': 'question-id',
                  'number': 1,
                  'part': 5,
                  'prompt': 'Choose an answer.',
                  'choices': ['A', 'B', 'C', 'D'],
                  'passage': null,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final exam = await repository.getExam('exam-id');

      expect(exam.questions.single.correctIndex, isNull);
      expect(exam.questions.single.choices, ['A', 'B', 'C', 'D']);
    },
  );

  test('exam list maps available sessions', () async {
    final repository = ApiStudentExamRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/api/exams');
        return http.Response(
          jsonEncode([
            {
              'id': 'exam-id',
              'title': 'Đề TOEIC',
              'durationMinutes': 75,
              'questionCount': 10,
              'sessions': [
                {
                  'id': 'morning-id',
                  'shift': 'Morning',
                  'sessionDate': '2026-10-20T00:00:00',
                  'sessionStart': '08:00:00',
                  'sessionEnd': '09:15:00',
                  'requiresSessionCode': true,
                },
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final exams = await repository.getPublishedExams();

    expect(exams.single.sessions.single.id, 'morning-id');
    expect(exams.single.sessions.single.shift, 'Morning');
    expect(exams.single.sessions.single.sessionDate, DateTime(2026, 10, 20));
    expect(exams.single.sessions.single.sessionStart, '08:00');
    expect(exams.single.sessions.single.requiresSessionCode, isTrue);
  });

  test('session code validation reports invalid codes', () async {
    final repository = ApiStudentExamRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/exams/exam-id/sessions/session-id/validate',
        );
        expect(jsonDecode(request.body), {'code': 'WRONG'});
        return http.Response(
          jsonEncode({
            'isValid': false,
            'message': 'Mã ca thi không chính xác.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      repository.validateSessionCode('exam-id', 'session-id', 'WRONG'),
      throwsA(isA<StudentExamApiException>()),
    );
  });

  test('submission sends selected choices and maps returned review', () async {
    final questions = [
      const ExamQuestion(
        id: 'question-1',
        number: 1,
        part: 5,
        prompt: 'First question',
        choices: ['A', 'B', 'C', 'D'],
      ),
      const ExamQuestion(
        id: 'question-2',
        number: 2,
        part: 5,
        prompt: 'Second question',
        choices: ['A', 'B', 'C', 'D'],
      ),
    ];
    final exam = Exam(
      id: 'exam-id',
      title: 'Đề TOEIC',
      description: 'Test',
      duration: const Duration(minutes: 75),
      questions: questions,
    );
    final repository = ApiStudentExamRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sessionId'], 'session-id');
        expect(body['sessionCode'], 'SANG20');
        expect(body['answers'], [
          {'questionId': 'question-1', 'answerIndex': 2},
        ]);
        return http.Response(
          jsonEncode({
            'totalQuestions': 2,
            'correct': 1,
            'incorrect': 0,
            'unanswered': 1,
            'answers': [
              {
                'questionId': 'question-1',
                'selectedAnswerIndex': 2,
                'correctAnswerIndex': 2,
                'hint': 'Đáp án đúng.',
              },
              {
                'questionId': 'question-2',
                'selectedAnswerIndex': null,
                'correctAnswerIndex': 0,
                'hint': null,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await repository.submitExam(
      exam,
      'session-id',
      [2, null],
      'SANG20',
    );

    expect(result.correct, 1);
    expect(result.unanswered, 1);
    expect(result.answers[0].hint, 'Đáp án đúng.');
    expect(result.answers[1].selectedIndex, isNull);
    expect(result.answers[1].correctIndex, 0);
  });
}
