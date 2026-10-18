import 'package:flutter/material.dart';

import '../data/student_exam_repository.dart';
import '../models/exam.dart';
import 'exam_screen.dart';

class ExamConfirmationScreen extends StatefulWidget {
  const ExamConfirmationScreen({
    super.key,
    required this.exam,
    required this.session,
    required this.repository,
  });

  final Exam exam;
  final ExamSession session;
  final StudentExamRepository repository;

  @override
  State<ExamConfirmationScreen> createState() => _ExamConfirmationScreenState();
}

class _ExamConfirmationScreenState extends State<ExamConfirmationScreen> {
  final _sessionCodeController = TextEditingController();
  bool _acceptedRules = true;
  bool _isValidatingCode = false;
  String? _sessionCodeError;

  @override
  void dispose() {
    _sessionCodeController.dispose();
    super.dispose();
  }

  Future<void> _startExam() async {
    setState(() {
      _isValidatingCode = true;
      _sessionCodeError = null;
    });
    try {
      final sessionCode = _sessionCodeController.text.trim();
      await widget.repository.validateSessionCode(
        widget.exam.id,
        widget.session.id,
        sessionCode.isEmpty ? null : sessionCode,
      );
      if (!mounted) return;
      final exam = widget.exam.withShuffledQuestions();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExamScreen(
            exam: exam,
            session: widget.session,
            repository: widget.repository,
            sessionCode: sessionCode,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sessionCodeError = error.toString());
    } finally {
      if (mounted) setState(() => _isValidatingCode = false);
    }
  }

  String _sessionLabel() =>
      widget.session.shift == 'Afternoon' ? 'CA CHIỀU' : 'CA SÁNG';

  String _scheduleLabel() {
    final date = widget.session.sessionDate;
    final start = widget.session.sessionStart;
    final end = widget.session.sessionEnd;
    final parts = <String>[];
    if (date != null) {
      parts.add(
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      );
    }
    if (start != null && end != null) parts.add('$start – $end');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF142B4A);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Xác nhận vào thi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE9EEF4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sessionLabel(),
                    style: TextStyle(
                      color: Color(0xFF5576D1),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.exam.title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.exam.questions.length} câu · ${widget.exam.duration.inMinutes} phút · Part 5, 6 & 7',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                  if (_scheduleLabel().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      _scheduleLabel(),
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Quy chế thi',
              style: TextStyle(
                color: navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const _RuleTile(
              number: '1',
              title: 'Làm bài trong thời gian quy định',
              detail: 'Đồng hồ bắt đầu đếm ngược khi bạn vào bài. Hết giờ, bài thi sẽ tự động được nộp.',
            ),
            const _RuleTile(
              number: '2',
              title: 'Thứ tự câu hỏi được xáo trộn',
              detail: 'Mỗi lượt thi có thứ tự câu hỏi riêng. Chọn đáp án để sang câu tiếp theo; bạn vẫn có thể quay lại đổi đáp án trước khi nộp bài.',
            ),
            const _RuleTile(
              number: '3',
              title: 'Không đóng ứng dụng khi đang thi',
              detail: 'Hãy kiểm tra kết nối mạng và chuẩn bị sẵn sàng trước khi bắt đầu.',
            ),
            const SizedBox(height: 16),
            Text(
              widget.session.requiresSessionCode
                  ? 'Mã ca thi'
                  : 'Mã ca thi (không bắt buộc)',
              style: TextStyle(
                color: navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sessionCodeController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (_sessionCodeError != null) {
                  setState(() => _sessionCodeError = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Nhập mã ca thi',
                prefixIcon: const Icon(Icons.key_outlined, size: 19),
                errorText: _sessionCodeError,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acceptedRules,
              onChanged: (value) =>
                  setState(() => _acceptedRules = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Tôi đã đọc và đồng ý tuân thủ quy chế thi.',
                style: TextStyle(color: Color(0xFF53647B), fontSize: 12),
              ),
              activeColor: const Color(0xFF2858DC),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _acceptedRules && !_isValidatingCode
                    ? _startExam
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2858DC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: _isValidatingCode
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  _isValidatingCode
                      ? 'Đang kiểm tra mã...'
                      : 'Vào thi · ${widget.exam.duration.inMinutes} phút',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9EEF4)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF3FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF2858DC),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF203453),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
