import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exam.dart';
import 'student_exam_repository.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5087',
);

class ApiStudentExamRepository implements StudentExamRepository {
  ApiStudentExamRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse(_apiBaseUrl).resolve(path);

  Future<dynamic> _request(
    Uri uri, {
    String method = 'GET',
    Object? body,
  }) async {
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);
    final responseBody = response.body;
    final statusCode = response.statusCode;
    if (statusCode < 200 || statusCode >= 300) {
      throw StudentExamApiException(_errorMessage(responseBody, statusCode));
    }
    try {
      return jsonDecode(responseBody);
    } on FormatException {
      throw const StudentExamApiException(
        'Máy chủ trả về dữ liệu không đúng định dạng.',
      );
    }
  }

  String _errorMessage(String body, int statusCode) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'] ?? payload['title'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
      }
    } on FormatException {
      // Use the status-based message when the server response is not JSON.
    }
    return 'Không thể kết nối máy chủ (HTTP $statusCode).';
  }

  @override
  Future<List<ExamSummary>> getPublishedExams() async {
    final payload = await _request(_uri('/api/exams'));
    if (payload is! List<dynamic>) {
      throw const StudentExamApiException(
        'Danh sách đề thi từ máy chủ không hợp lệ.',
      );
    }
    return payload
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const StudentExamApiException(
              'Thông tin đề thi không hợp lệ.',
            );
          }
          return ExamSummary(
            id: _requiredString(item, 'id'),
            title: _requiredString(item, 'title'),
            duration: Duration(minutes: _requiredInt(item, 'durationMinutes')),
            questionCount: _requiredInt(item, 'questionCount'),
            sessions: _requiredList(item, 'sessions')
                .map((session) {
                  if (session is! Map<String, dynamic>) {
                    throw const StudentExamApiException(
                      'Thông tin ca thi không hợp lệ.',
                    );
                  }
                  return ExamSession(
                    id: _requiredString(session, 'id'),
                    shift: _requiredString(session, 'shift'),
                    sessionDate: _optionalDate(session, 'sessionDate'),
                    sessionStart: _optionalTime(session, 'sessionStart'),
                    sessionEnd: _optionalTime(session, 'sessionEnd'),
                    requiresSessionCode: session['requiresSessionCode'] == true,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Exam> getExam(String id) async {
    final payload = await _request(
      _uri('/api/exams/${Uri.encodeComponent(id)}'),
    );
    if (payload is! Map<String, dynamic>) {
      throw const StudentExamApiException('Thông tin đề thi không hợp lệ.');
    }
    final questions = payload['questions'];
    if (questions is! List<dynamic> || questions.isEmpty) {
      throw const StudentExamApiException('Đề thi chưa có câu hỏi.');
    }
    return Exam(
      id: _requiredString(payload, 'id'),
      title: _requiredString(payload, 'title'),
      description: 'TOEIC Reading • Part 5, 6 & 7',
      duration: Duration(minutes: _requiredInt(payload, 'durationMinutes')),
      questions: questions
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const StudentExamApiException(
                'Nội dung câu hỏi không hợp lệ.',
              );
            }
            final choices = item['choices'];
            if (choices is! List<dynamic> ||
                choices.length != 4 ||
                choices.any((choice) => choice is! String)) {
              throw const StudentExamApiException(
                'Mỗi câu hỏi phải có đủ bốn lựa chọn.',
              );
            }
            return ExamQuestion(
              id: _requiredString(item, 'id'),
              number: _requiredInt(item, 'number'),
              part: _requiredInt(item, 'part'),
              prompt: _requiredString(item, 'prompt'),
              choices: choices.cast<String>(),
              passage: item['passage'] as String?,
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Future<void> validateSessionCode(
    String examId,
    String sessionId,
    String? code,
  ) async {
    final payload = await _request(
      _uri(
        '/api/exams/${Uri.encodeComponent(examId)}/sessions/${Uri.encodeComponent(sessionId)}/validate',
      ),
      method: 'POST',
      body: {'code': code},
    );
    if (payload is! Map<String, dynamic> || payload['isValid'] is! bool) {
      throw const StudentExamApiException(
        'Phản hồi kiểm tra mã ca thi không hợp lệ.',
      );
    }
    if (payload['isValid'] != true) {
      final message = payload['message'];
      throw StudentExamApiException(
        message is String && message.isNotEmpty
            ? message
            : 'Mã ca thi không chính xác.',
      );
    }
  }

  @override
  Future<ExamSubmissionResult> submitExam(
    Exam exam,
    String sessionId,
    List<int?> answers,
    String? sessionCode,
  ) async {
    if (answers.length != exam.questions.length ||
        exam.questions.any((question) => question.id == null)) {
      throw const StudentExamApiException(
        'Không thể gửi bài thi thiếu thông tin câu hỏi.',
      );
    }
    final payload = await _request(
      _uri('/api/exams/${Uri.encodeComponent(exam.id)}/attempts'),
      method: 'POST',
      body: {
        'sessionId': sessionId,
        'sessionCode': sessionCode,
        'answers': [
          for (var index = 0; index < exam.questions.length; index++)
            if (answers[index] != null)
              {
                'questionId': exam.questions[index].id,
                'answerIndex': answers[index],
              },
        ],
      },
    );
    if (payload is! Map<String, dynamic>) {
      throw const StudentExamApiException('Kết quả chấm thi không hợp lệ.');
    }
    final reviews = payload['answers'];
    if (reviews is! List<dynamic>) {
      throw const StudentExamApiException('Thiếu thông tin xem lại đáp án.');
    }
    final reviewsByQuestion = <String, ExamAnswerReview>{};
    for (final item in reviews) {
      if (item is! Map<String, dynamic>) {
        throw const StudentExamApiException('Thông tin đáp án không hợp lệ.');
      }
      final questionId = _requiredString(item, 'questionId');
      reviewsByQuestion[questionId] = ExamAnswerReview(
        selectedIndex: _optionalInt(item, 'selectedAnswerIndex'),
        correctIndex: _requiredInt(item, 'correctAnswerIndex'),
        hint: item['hint'] as String?,
      );
    }
    final orderedReviews = exam.questions
        .map((question) {
          final review = reviewsByQuestion[question.id];
          if (review == null) {
            throw const StudentExamApiException(
              'Máy chủ thiếu kết quả của một câu hỏi.',
            );
          }
          return review;
        })
        .toList(growable: false);
    return ExamSubmissionResult(
      totalQuestions: _requiredInt(payload, 'totalQuestions'),
      correct: _requiredInt(payload, 'correct'),
      incorrect: _requiredInt(payload, 'incorrect'),
      unanswered: _requiredInt(payload, 'unanswered'),
      answers: orderedReviews,
    );
  }

  String _requiredString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw StudentExamApiException('Thiếu trường "$key" trong dữ liệu đề thi.');
  }

  int _requiredInt(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is int) return value;
    throw StudentExamApiException(
      'Trường "$key" trong dữ liệu đề thi không hợp lệ.',
    );
  }

  List<dynamic> _requiredList(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is List<dynamic> && value.isNotEmpty) return value;
    throw StudentExamApiException(
      'Thiếu danh sách "$key" trong dữ liệu đề thi.',
    );
  }

  int? _optionalInt(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null || value is int) return value as int?;
    throw StudentExamApiException('Trường "$key" trong kết quả không hợp lệ.');
  }

  DateTime? _optionalDate(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is String) {
      final date = DateTime.tryParse(value);
      if (date != null) return date;
    }
    throw StudentExamApiException('Trường "$key" trong lịch thi không hợp lệ.');
  }

  String? _optionalTime(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is String && RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(value)) {
      return value.substring(0, 5);
    }
    throw StudentExamApiException('Trường "$key" trong lịch thi không hợp lệ.');
  }
}

class StudentExamApiException implements Exception {
  const StudentExamApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
