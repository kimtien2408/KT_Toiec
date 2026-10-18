import 'dart:async';

import 'package:flutter/material.dart';

import '../data/student_exam_repository.dart';
import '../models/exam.dart';
import 'result_screen.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    required this.exam,
    required this.session,
    required this.repository,
    required this.sessionCode,
  });

  final Exam exam;
  final ExamSession session;
  final StudentExamRepository repository;
  final String sessionCode;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late final List<int?> _answers;
  late final List<bool> _marked;
  late int _remainingSeconds;
  int _currentIndex = 0;
  Timer? _timer;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;

  ExamQuestion get _question => widget.exam.questions[_currentIndex];

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(widget.exam.questions.length, null);
    _marked = List<bool>.filled(widget.exam.questions.length, false);
    _remainingSeconds = widget.exam.duration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        _remainingSeconds = 0;
        unawaited(_submit());
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_hasSubmitted || _isSubmitting || !mounted) return;
    _isSubmitting = true;
    setState(() {});
    _timer?.cancel();
    try {
      final result = await widget.repository.submitExam(
        widget.exam,
        widget.session.id,
        List<int?>.unmodifiable(_answers),
        widget.sessionCode.isEmpty ? null : widget.sessionCode,
      );
      if (!mounted) return;
      _hasSubmitted = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            exam: widget.exam,
            result: result,
            session: widget.session,
            durationSpent:
                widget.exam.duration - Duration(seconds: _remainingSeconds),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _isSubmitting = false;
      if (_remainingSeconds > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_remainingSeconds <= 1) {
            _timer?.cancel();
            setState(() => _remainingSeconds = 0);
            unawaited(_submit());
          } else {
            setState(() => _remainingSeconds--);
          }
        });
      }
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không nộp được bài thi: $error')));
    }
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _answers.where((answer) => answer == null).length;
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nộp bài thi?'),
        content: Text(
          unanswered == 0
              ? 'Bạn đã hoàn thành tất cả câu hỏi. Xác nhận nộp bài?'
              : 'Bạn còn $unanswered câu chưa trả lời. Bạn vẫn muốn nộp bài?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Làm tiếp'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
    if (shouldSubmit == true) await _submit();
  }

  void _goToQuestion(int index) {
    setState(() => _currentIndex = index);
  }

  void _selectAnswer(int choiceIndex) {
    setState(() {
      _answers[_currentIndex] = choiceIndex;
      if (_currentIndex < widget.exam.questions.length - 1) {
        _currentIndex++;
      }
    });
  }

  Future<void> _showQuestionPalette() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bảng câu hỏi',
                          style: TextStyle(
                            color: Color(0xFF142B4A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng bảng câu hỏi',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_answers.where((answer) => answer != null).length}/${_answers.length} câu đã trả lời · ${_marked.where((marked) => marked).length} câu đánh dấu',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QuestionNavigator(
                    answers: _answers,
                    marked: _marked,
                    currentIndex: _currentIndex,
                    onSelect: (index) {
                      _goToQuestion(index);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remainingSeconds <= 300;
    final selectedAnswer = _answers[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _confirmLeave(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'Đang làm bài',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Bảng câu hỏi',
            onPressed: _showQuestionPalette,
            icon: const Icon(Icons.grid_view_rounded),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isUrgent
                  ? const Color(0xFFFFE8E6)
                  : const Color(0xFFE8F6F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 17,
                  color: isUrgent
                      ? const Color(0xFFD84E43)
                      : const Color(0xFF1AA89A),
                ),
                const SizedBox(width: 6),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    color: isUrgent
                        ? const Color(0xFFD84E43)
                        : const Color(0xFF142B4A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.exam.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentIndex + 1}/${widget.exam.questions.length}',
                      style: const TextStyle(
                        color: Color(0xFF142B4A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / widget.exam.questions.length,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE4EAF0),
                    color: const Color(0xFF1AA89A),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_question.passage != null) ...[
                    _PassageCard(
                      part: _question.part,
                      content: _question.passage!,
                    ),
                    const SizedBox(height: 17),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: const Color(0xFFE9EEF4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF4F3),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'PART ${_question.part}',
                                style: const TextStyle(
                                  color: Color(0xFF15877D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              'Câu ${_question.number}',
                              style: const TextStyle(
                                color: Color(0xFF718096),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: _marked[_currentIndex]
                                  ? 'Bỏ đánh dấu câu hỏi'
                                  : 'Đánh dấu câu hỏi',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(
                                () => _marked[_currentIndex] =
                                    !_marked[_currentIndex],
                              ),
                              icon: Icon(
                                _marked[_currentIndex]
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: _marked[_currentIndex]
                                    ? const Color(0xFFE19848)
                                    : const Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        Text(
                          _question.prompt,
                          style: const TextStyle(
                            color: Color(0xFF142B4A),
                            fontSize: 17,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 17),
                        ...List.generate(
                          _question.choices.length,
                          (choiceIndex) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _AnswerOption(
                              label: String.fromCharCode(65 + choiceIndex),
                              text: _question.choices[choiceIndex],
                              selected: selectedAnswer == choiceIndex,
                              onTap: () => _selectAnswer(choiceIndex),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionNavigator(
                    answers: _answers,
                    marked: _marked,
                    currentIndex: _currentIndex,
                    onSelect: _goToQuestion,
                  ),
                ],
              ),
            ),
          ),
          _BottomControls(
            currentIndex: _currentIndex,
            questionCount: widget.exam.questions.length,
            onPrevious: _currentIndex == 0
                ? null
                : () => _goToQuestion(_currentIndex - 1),
            onNext: _currentIndex == widget.exam.questions.length - 1
                ? null
                : () => _goToQuestion(_currentIndex + 1),
            onSubmit: _confirmSubmit,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thoát bài thi?'),
        content: const Text(
          'Tiến độ làm bài sẽ bị mất nếu bạn thoát ngay bây giờ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) Navigator.of(context).pop();
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.part, required this.content});

  final int part;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.article_outlined,
                color: Color(0xFF5576D1),
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                part == 6 ? 'ĐOẠN VĂN • PART 6' : 'BÀI ĐỌC • PART 7',
                style: const TextStyle(
                  color: Color(0xFF4B64AD),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            content,
            style: const TextStyle(
              color: Color(0xFF34445A),
              fontSize: 13,
              height: 1.58,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1AA89A) : const Color(0xFFDCE3EB);

    return Material(
      color: selected ? const Color(0xFFE9F7F4) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1AA89A) : Colors.white,
                  shape: BoxShape.circle,
                  border: selected
                      ? null
                      : Border.all(color: const Color(0xFFDCE3EB)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF637187),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: const Color(0xFF34445A),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF1AA89A),
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.answers,
    required this.marked,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<int?> answers;
  final List<bool> marked;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9EEF4)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh sách câu hỏi',
            style: TextStyle(
              color: Color(0xFF142B4A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(answers.length, (index) {
              final isCurrent = index == currentIndex;
              final isAnswered = answers[index] != null;
              final isMarked = marked[index];
              final background = isCurrent
                  ? const Color(0xFF142B4A)
                  : isMarked
                  ? const Color(0xFFFFF1D9)
                  : isAnswered
                  ? const Color(0xFFE5F5F0)
                  : const Color(0xFFF1F4F8);
              final foreground = isCurrent
                  ? Colors.white
                  : isMarked
                  ? const Color(0xFFB87316)
                  : isAnswered
                  ? const Color(0xFF16866F)
                  : const Color(0xFF718096);
              return InkWell(
                onTap: () => onSelect(index),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _PaletteLegend(color: const Color(0xFFF1F4F8), label: 'Chưa làm'),
              _PaletteLegend(color: const Color(0xFFE5F5F0), label: 'Đã làm'),
              _PaletteLegend(color: const Color(0xFFFFF1D9), label: 'Đánh dấu'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteLegend extends StatelessWidget {
  const _PaletteLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF718096), fontSize: 10),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.currentIndex,
    required this.questionCount,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final int currentIndex;
  final int questionCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EEF4))),
      ),
      child: Row(
        children: [
          IconButton.outlined(
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF142B4A),
              side: const BorderSide(color: Color(0xFFDCE3EB)),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: OutlinedButton(
              onPressed: onSubmit,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF142B4A),
                side: const BorderSide(color: Color(0xFFDCE3EB)),
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Nộp bài',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 9),
          IconButton.filled(
            onPressed: onNext,
            icon: Icon(
              currentIndex == questionCount - 1
                  ? Icons.done_rounded
                  : Icons.arrow_forward_rounded,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF142B4A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
