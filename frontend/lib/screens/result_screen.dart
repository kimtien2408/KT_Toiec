import 'package:flutter/material.dart';

import '../models/exam.dart';
import 'review_screen.dart';

const _navy = Color(0xFF183B59);
const _teal = Color(0xFF178E83);
const _muted = Color(0xFF718096);

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.exam,
    required this.result,
    required this.session,
    required this.durationSpent,
  });

  final Exam exam;
  final ExamSubmissionResult result;
  final ExamSession session;
  final Duration durationSpent;

  @override
  Widget build(BuildContext context) {
    final accuracy = result.totalQuestions == 0
        ? 0
        : (result.correct / result.totalQuestions * 100).round();
    final parts = <int, ({int total, int correct})>{};
    for (var index = 0; index < exam.questions.length; index++) {
      final question = exam.questions[index];
      final review = result.answers[index];
      final current = parts[question.part] ?? (total: 0, correct: 0);
      parts[question.part] = (
        total: current.total + 1,
        correct:
            current.correct +
            (review.selectedIndex == review.correctIndex ? 1 : 0),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        automaticallyImplyLeading: false,
        title: const Text(
          'Kết quả bài thi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Về trang chủ',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 7, 20, 26),
          children: [
            const Text(
              'Bài thi đã hoàn thành!',
              style: TextStyle(
                color: _navy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${exam.title} · ${session.shift == 'Afternoon' ? 'Ca chiều' : 'Ca sáng'}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 21, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE7ECF1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF20344D).withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 144,
                    height: 144,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: accuracy / 100,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0xFFE8EEF2),
                            color: _teal,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$accuracy%',
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'ĐỘ CHÍNH XÁC',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '${result.correct} / ${result.totalQuestions} câu đúng',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Thời gian làm bài: ${_formatDuration(durationSpent)}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Kết quả luyện tập, không phải điểm TOEIC quy đổi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _ResultCount(
                    count: result.correct,
                    label: 'Câu đúng',
                    color: const Color(0xFF15966F),
                    background: const Color(0xFFE8F6F0),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ResultCount(
                    count: result.incorrect,
                    label: 'Câu sai',
                    color: const Color(0xFFD45E56),
                    background: const Color(0xFFFFEFED),
                    icon: Icons.cancel_outlined,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ResultCount(
                    count: result.unanswered,
                    label: 'Bỏ qua',
                    color: const Color(0xFF8A94A3),
                    background: const Color(0xFFF0F2F5),
                    icon: Icons.remove_circle_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Kết quả theo từng phần',
              style: TextStyle(
                color: _navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final part in parts.entries)
              _PartProgress(
                part: part.key,
                correct: part.value.correct,
                total: part.value.total,
              ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(exam: exam, result: result),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
                label: const Text(
                  'Xem lại đáp án & gợi ý',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 47,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: Color(0xFFDDE5EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Về danh sách đề thi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({
    required this.count,
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final int count;
  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PartProgress extends StatelessWidget {
  const _PartProgress({
    required this.part,
    required this.correct,
    required this.total,
  });

  final int part;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : correct / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF1)),
      ),
      child: Row(
        children: [
          Container(
            width: 41,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'P$part',
              style: const TextStyle(
                color: _teal,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Part $part',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE8EEF2),
                    color: _teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$correct/$total',
            style: const TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
