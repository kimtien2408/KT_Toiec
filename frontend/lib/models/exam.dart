import 'dart:math';

class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.questions,
  });

  final String id;
  final String title;
  final String description;
  final Duration duration;
  final List<ExamQuestion> questions;

  Exam withShuffledQuestions({Random? random}) {
    final shuffledQuestions = [...questions]..shuffle(random);
    if (shuffledQuestions.length > 1) {
      var hasChangedOrder = false;
      for (var index = 0; index < questions.length; index++) {
        if (shuffledQuestions[index] != questions[index]) {
          hasChangedOrder = true;
          break;
        }
      }
      if (!hasChangedOrder) {
        final firstQuestion = shuffledQuestions[0];
        shuffledQuestions[0] = shuffledQuestions[1];
        shuffledQuestions[1] = firstQuestion;
      }
    }
    return Exam(
      id: id,
      title: title,
      description: description,
      duration: duration,
      questions: List.unmodifiable(shuffledQuestions),
    );
  }
}

class ExamSummary {
  const ExamSummary({
    required this.id,
    required this.title,
    required this.duration,
    required this.questionCount,
    required this.sessions,
  });

  final String id;
  final String title;
  final Duration duration;
  final int questionCount;
  final List<ExamSession> sessions;
}

class ExamSession {
  const ExamSession({
    required this.id,
    required this.shift,
    this.sessionDate,
    this.sessionStart,
    this.sessionEnd,
    required this.requiresSessionCode,
  });

  final String id;
  final String shift;
  final DateTime? sessionDate;
  final String? sessionStart;
  final String? sessionEnd;
  final bool requiresSessionCode;
}

class ExamQuestion {
  const ExamQuestion({
    this.id,
    required this.number,
    required this.part,
    required this.prompt,
    required this.choices,
    this.correctIndex,
    this.passage,
    this.hint,
  });

  final String? id;
  final int number;
  final int part;
  final String prompt;
  final List<String> choices;
  final int? correctIndex;
  final String? passage;
  final String? hint;
}

class ExamAnswerReview {
  const ExamAnswerReview({
    required this.selectedIndex,
    required this.correctIndex,
    this.hint,
  });

  final int? selectedIndex;
  final int correctIndex;
  final String? hint;
}

class ExamSubmissionResult {
  const ExamSubmissionResult({
    required this.totalQuestions,
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.answers,
  });

  final int totalQuestions;
  final int correct;
  final int incorrect;
  final int unanswered;
  final List<ExamAnswerReview> answers;
}
