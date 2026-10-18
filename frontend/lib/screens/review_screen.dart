import 'package:flutter/material.dart';

import '../models/exam.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.exam, required this.result});

  final Exam exam;
  final ExamSubmissionResult result;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;
  int _visibleIndex = 0;

  List<int> get _questionIndices {
    return [
      for (var index = 0; index < widget.exam.questions.length; index++)
        if (_matchesFilter(index)) index,
    ];
  }

  bool _matchesFilter(int index) {
    final answer = widget.result.answers[index];
    switch (_filter) {
      case _ReviewFilter.all:
        return true;
      case _ReviewFilter.incorrect:
        return answer.selectedIndex != null &&
            answer.selectedIndex != answer.correctIndex;
      case _ReviewFilter.unanswered:
        return answer.selectedIndex == null;
    }
  }

  void _selectFilter(_ReviewFilter filter) {
    setState(() {
      _filter = filter;
      _visibleIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final indices = _questionIndices;
    final index = indices.isEmpty ? 0 : indices[_visibleIndex];
    final question = widget.exam.questions[index];
    final review = widget.result.answers[index];
    final selectedIndex = review.selectedIndex;
    final isCorrect = selectedIndex == review.correctIndex;
    final statusColor = selectedIndex == null
        ? const Color(0xFF8A94A3)
        : isCorrect
        ? const Color(0xFF168A68)
        : const Color(0xFFD65750);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        leading: IconButton(
          tooltip: 'Quay lại kết quả',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Xem lại đáp án',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 13),
              child: Row(
                children: [
                  for (final filter in _ReviewFilter.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _FilterTab(
                          label: filter.label,
                          selected: _filter == filter,
                          onTap: () => _selectFilter(filter),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: indices.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có câu hỏi trong mục này.',
                        style: TextStyle(color: Color(0xFF718096)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F4F1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'PART ${question.part}',
                                style: const TextStyle(
                                  color: Color(0xFF16877D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              'Câu ${question.number}',
                              style: const TextStyle(
                                color: Color(0xFF718096),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_visibleIndex + 1}/${indices.length}',
                              style: const TextStyle(
                                color: Color(0xFF718096),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (question.passage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2F5),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              question.passage!,
                              style: const TextStyle(
                                color: Color(0xFF435A6D),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE6EBF0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'CÂU HỎI',
                                      style: TextStyle(
                                        color: Color(0xFF8290A0),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    selectedIndex == null
                                        ? Icons.remove_circle_outline_rounded
                                        : isCorrect
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 18,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    selectedIndex == null
                                        ? 'Bỏ qua'
                                        : isCorrect
                                        ? 'Chính xác'
                                        : 'Chưa chính xác',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                question.prompt,
                                style: const TextStyle(
                                  color: Color(0xFF183B59),
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 17),
                              for (
                                var choiceIndex = 0;
                                choiceIndex < question.choices.length;
                                choiceIndex++
                              )
                                _ReviewChoice(
                                  label: String.fromCharCode(65 + choiceIndex),
                                  text: question.choices[choiceIndex],
                                  isCorrect: choiceIndex == review.correctIndex,
                                  isSelected: choiceIndex == selectedIndex,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6F2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                color: Color(0xFF178E83),
                                size: 19,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gợi ý giải',
                                      style: TextStyle(
                                        color: Color(0xFF16776F),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      review.hint?.trim().isNotEmpty == true
                                          ? review.hint!
                                          : 'Đáp án đúng là ${String.fromCharCode(65 + review.correctIndex)}. Hãy xem lại lựa chọn được đánh dấu để củng cố kiến thức.',
                                      style: const TextStyle(
                                        color: Color(0xFF4E6F70),
                                        fontSize: 12,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            if (indices.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 11, 20, 15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE9EEF2)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _visibleIndex == 0
                            ? null
                            : () => setState(() => _visibleIndex--),
                        icon: const Icon(Icons.arrow_back_rounded, size: 17),
                        label: const Text('Câu trước'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _visibleIndex == indices.length - 1
                            ? null
                            : () => setState(() => _visibleIndex++),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('Câu tiếp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF178E83),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ReviewFilter {
  all('Tất cả'),
  incorrect('Sai'),
  unanswered('Bỏ qua');

  const _ReviewFilter(this.label);

  final String label;
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF178E83) : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? const Color(0xFF178E83) : const Color(0xFFE3E9EF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF617489),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReviewChoice extends StatelessWidget {
  const _ReviewChoice({
    required this.label,
    required this.text,
    required this.isCorrect,
    required this.isSelected,
  });

  final String label;
  final String text;
  final bool isCorrect;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect
        ? const Color(0xFF168A68)
        : isSelected
        ? const Color(0xFFD65750)
        : const Color(0xFF778596);
    final background = isCorrect
        ? const Color(0xFFE9F6F0)
        : isSelected
        ? const Color(0xFFFFEFED)
        : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isCorrect || isSelected)
              ? color.withValues(alpha: 0.4)
              : const Color(0xFFE8EDF1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isCorrect || isSelected)
                  ? color.withValues(alpha: 0.12)
                  : const Color(0xFFF1F4F7),
              shape: BoxShape.circle,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isCorrect || isSelected
                    ? const Color(0xFF33475B)
                    : const Color(0xFF66778A),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (isCorrect)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF168A68),
              size: 18,
            )
          else if (isSelected)
            const Icon(
              Icons.cancel_rounded,
              color: Color(0xFFD65750),
              size: 18,
            ),
        ],
      ),
    );
  }
}
