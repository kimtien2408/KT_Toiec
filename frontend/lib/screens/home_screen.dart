import 'package:flutter/material.dart';

import '../data/student_exam_repository.dart';
import '../models/exam.dart';
import 'exam_confirmation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repository});

  final StudentExamRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F4F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Color(0xFF168F83),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Readwise',
                    style: TextStyle(
                      color: Color(0xFF183B59),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Thông báo',
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF51677D),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFFDCEAEF),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF416078),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Xin chào 👋',
                style: TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sẵn sàng luyện tập?',
                style: TextStyle(
                  color: Color(0xFF183B59),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              const _PracticeBanner(),
              const SizedBox(height: 22),
              _PublishedExamList(repository: repository),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      color: Color(0xFF168F83),
                      size: 21,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tiến độ làm bài của bạn được tự động lưu.',
                        style: TextStyle(
                          color: Color(0xFF426B69),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE6F4F1),
        onDestinationSelected: (index) {
          if (index != 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mục này sẽ sớm được cập nhật.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Đề thi',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class _PracticeBanner extends StatelessWidget {
  const _PracticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF157D78), Color(0xFF25A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chinh phục TOEIC Reading',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Luyện tập mỗi ngày, tiến bộ mỗi ngày',
                  style: TextStyle(color: Color(0xFFDDF5F0), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.auto_graph_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 38,
          ),
        ],
      ),
    );
  }
}

class _PublishedExamList extends StatefulWidget {
  const _PublishedExamList({required this.repository});

  final StudentExamRepository repository;

  @override
  State<_PublishedExamList> createState() => _PublishedExamListState();
}

class _PublishedExamListState extends State<_PublishedExamList> {
  late Future<List<ExamSummary>> _exams;
  String? _loadingSessionId;
  String _selectedShift = 'All';

  @override
  void initState() {
    super.initState();
    _exams = widget.repository.getPublishedExams();
  }

  void _retry() {
    setState(() {
      _exams = widget.repository.getPublishedExams();
    });
  }

  Future<void> _openExam(ExamSummary summary, ExamSession session) async {
    setState(() => _loadingSessionId = session.id);
    try {
      final exam = await widget.repository.getExam(summary.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamConfirmationScreen(
            exam: exam,
            session: session,
            repository: widget.repository,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không tải được đề thi: $error')));
    } finally {
      if (mounted) setState(() => _loadingSessionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExamSummary>>(
      future: _exams,
      builder: (context, snapshot) {
        final exams = snapshot.data ?? const <ExamSummary>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Đề thi của bạn',
                    style: TextStyle(
                      color: Color(0xFF183B59),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới danh sách đề thi',
                  onPressed: _retry,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF587086),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              children: [
                _ShiftFilter(
                  label: 'Tất cả ca thi',
                  selected: _selectedShift == 'All',
                  onTap: () => setState(() => _selectedShift = 'All'),
                ),
                _ShiftFilter(
                  label: 'Ca sáng',
                  selected: _selectedShift == 'Morning',
                  onTap: () => setState(() => _selectedShift = 'Morning'),
                ),
                _ShiftFilter(
                  label: 'Ca chiều',
                  selected: _selectedShift == 'Afternoon',
                  onTap: () => setState(() => _selectedShift = 'Afternoon'),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _ExamListMessage(
                icon: Icons.cloud_off_outlined,
                message: 'Không tải được danh sách đề thi.',
                actionLabel: 'Thử lại',
                onPressed: _retry,
              )
            else if (exams.isEmpty)
              const _ExamListMessage(
                icon: Icons.inbox_outlined,
                message: 'Chưa có đề thi được bật. Hãy làm mới sau khi giảng viên kích hoạt đề.',
              )
            else
              _buildSessionCards(exams),
          ],
        );
      },
    );
  }

  Widget _buildSessionCards(List<ExamSummary> exams) {
    final entries = <({ExamSummary exam, ExamSession session})>[];
    for (final exam in exams) {
      for (final session in exam.sessions) {
        if (_selectedShift == 'All' || session.shift == _selectedShift) {
          entries.add((exam: exam, session: session));
        }
      }
    }
    if (entries.isEmpty) {
      return const _ExamListMessage(
        icon: Icons.event_busy_outlined,
        message: 'Không có ca thi phù hợp với bộ lọc này.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _SessionCard(
            summary: entries[i].exam,
            session: entries[i].session,
            isHighlighted: i == 0,
            isLoading: _loadingSessionId == entries[i].session.id,
            onStart: () => _openExam(entries[i].exam, entries[i].session),
          ),
          if (i < entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ShiftFilter extends StatelessWidget {
  const _ShiftFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF617489),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF178E83),
      side: BorderSide(
        color: selected ? const Color(0xFF178E83) : const Color(0xFFE4EAF0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 5),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.summary,
    required this.session,
    required this.isHighlighted,
    required this.isLoading,
    required this.onStart,
  });

  final ExamSummary summary;
  final ExamSession session;
  final bool isHighlighted;
  final bool isLoading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final primary = isHighlighted ? Colors.white : const Color(0xFF183B59);
    final secondary = isHighlighted
        ? const Color(0xFFDDF3F0)
        : const Color(0xFF718096);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF178E83) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF178E83)
              : const Color(0xFFE6EBF0),
        ),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: const Color(0xFF178E83).withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: isHighlighted ? Colors.white : const Color(0xFF178E83),
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TOEIC Reading · ${_shiftLabel(session.shift)}',
                      style: TextStyle(color: secondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: secondary, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SessionFact(
                icon: Icons.help_outline_rounded,
                text: '${summary.questionCount} câu',
                color: secondary,
              ),
              const SizedBox(width: 14),
              _SessionFact(
                icon: Icons.schedule_rounded,
                text: '${summary.duration.inMinutes} phút',
                color: secondary,
              ),
              const SizedBox(width: 14),
              _SessionFact(
                icon: Icons.event_outlined,
                text: _sessionDateLabel(session),
                color: secondary,
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: isHighlighted
                ? FilledButton(
                    onPressed: isLoading ? null : onStart,
                    style: FilledButton.styleFrom(
                      foregroundColor: const Color(0xFF147E75),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Bắt đầu làm bài',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  )
                : OutlinedButton(
                    onPressed: isLoading ? null : onStart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF178E83),
                      side: const BorderSide(color: Color(0xFFB9DDD7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Bắt đầu làm bài',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionFact extends StatelessWidget {
  const _SessionFact({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamListMessage extends StatelessWidget {
  const _ExamListMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF718096), size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF53647B), fontSize: 12),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _shiftLabel(String shift) =>
    shift == 'Afternoon' ? 'Ca chiều' : 'Ca sáng';

String _sessionDateLabel(ExamSession session) {
  final date = session.sessionDate;
  if (date == null) return 'Lịch thi';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
