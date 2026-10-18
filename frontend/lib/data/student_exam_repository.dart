import '../models/exam.dart';

abstract interface class StudentExamRepository {
  Future<List<ExamSummary>> getPublishedExams();

  Future<Exam> getExam(String id);

  Future<void> validateSessionCode(
    String examId,
    String sessionId,
    String? code,
  );

  Future<ExamSubmissionResult> submitExam(
    Exam exam,
    String sessionId,
    List<int?> answers,
    String? sessionCode,
  );
}
