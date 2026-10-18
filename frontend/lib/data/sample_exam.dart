import '../models/exam.dart';

const sampleExam = Exam(
  id: 'reading-demo-01',
  title: 'TOEIC Reading - Đề luyện tập',
  description: 'Luyện tập ngữ pháp, điền câu và đọc hiểu',
  duration: Duration(minutes: 75),
  questions: [
    ExamQuestion(
      number: 1,
      part: 5,
      prompt: 'All employees must submit _____ travel receipts by Friday.',
      choices: ['they', 'their', 'theirs', 'them'],
      correctIndex: 1,
      hint: 'Cần một tính từ sở hữu đứng trước danh từ “travel receipts”.',
    ),
    ExamQuestion(
      number: 2,
      part: 5,
      prompt: 'The new conference room is _____ than the previous one.',
      choices: ['spacious', 'more spacious', 'most spacious', 'spaciously'],
      correctIndex: 1,
      hint: 'So sánh hơn của tính từ dài thường dùng “more”.',
    ),
    ExamQuestion(
      number: 3,
      part: 5,
      prompt: 'Ms. Kim will contact you as soon as the schedule _____.',
      choices: ['finalizes', 'will finalize', 'is finalized', 'finalizing'],
      correctIndex: 2,
      hint: 'Lịch trình là đối tượng được hoàn tất, nên dùng câu bị động.',
    ),
    ExamQuestion(
      number: 4,
      part: 5,
      prompt: 'The package was delivered _____ than we had expected.',
      choices: ['early', 'earliest', 'earlier', 'more early'],
      correctIndex: 2,
      hint: 'Cấu trúc “than” cần dạng so sánh hơn.',
    ),
    ExamQuestion(
      number: 5,
      part: 6,
      passage:
          'To: All staff\n'
          'From: Human Resources\n'
          'Subject: Updated office hours\n\n'
          'Beginning next Monday, the main office will open at 8:30 A.M. '
          'Employees who need access before that time should contact the '
          'building manager. The updated schedule is intended to reduce '
          'energy use while still providing convenient service to visitors.',
      prompt: 'The main office will _____ at 8:30 A.M. starting next Monday.',
      choices: ['open', 'opens', 'opened', 'opening'],
      correctIndex: 0,
      hint: 'Sau “will” dùng động từ nguyên mẫu.',
    ),
    ExamQuestion(
      number: 6,
      part: 6,
      passage:
          'To: All staff\n'
          'From: Human Resources\n'
          'Subject: Updated office hours\n\n'
          'Beginning next Monday, the main office will open at 8:30 A.M. '
          'Employees who need access before that time should contact the '
          'building manager. The updated schedule is intended to reduce '
          'energy use while still providing convenient service to visitors.',
      prompt: 'Who should employees contact if they need early access?',
      choices: [
        'The office director',
        'The building manager',
        'The Human Resources team',
        'A visitor services agent',
      ],
      correctIndex: 1,
      hint: 'Tìm câu có cụm “need access before that time”.',
    ),
    ExamQuestion(
      number: 7,
      part: 6,
      passage:
          'To: All staff\n'
          'From: Human Resources\n'
          'Subject: Updated office hours\n\n'
          'Beginning next Monday, the main office will open at 8:30 A.M. '
          'Employees who need access before that time should contact the '
          'building manager. The updated schedule is intended to reduce '
          'energy use while still providing convenient service to visitors.',
      prompt: 'What is one goal of the updated schedule?',
      choices: [
        'To increase the number of employees',
        'To reduce energy consumption',
        'To move the main office',
        'To shorten visitor appointments',
      ],
      correctIndex: 1,
      hint: 'Mục đích được nêu trong câu cuối của thông báo.',
    ),
    ExamQuestion(
      number: 8,
      part: 7,
      passage:
          'RIVERSIDE ART MUSEUM\n'
          'Visitor Information\n\n'
          'The Riverside Art Museum will reopen its east gallery on June 12 '
          'after a six-week renovation. The gallery will feature works by '
          'local artists and a new interactive exhibit. Museum members may '
          'attend a preview on June 11 from 6:00 to 8:00 P.M. General '
          'admission is \$12, and visitors under 16 enter free when '
          'accompanied by an adult. Tickets can be purchased at the front '
          'desk or through the museum website.',
      prompt: 'When will the east gallery reopen to the public?',
      choices: ['June 11', 'June 12', 'June 16', 'June 21'],
      correctIndex: 1,
      hint: 'Phân biệt ngày mở cửa lại với ngày xem trước dành cho hội viên.',
    ),
    ExamQuestion(
      number: 9,
      part: 7,
      passage:
          'RIVERSIDE ART MUSEUM\n'
          'Visitor Information\n\n'
          'The Riverside Art Museum will reopen its east gallery on June 12 '
          'after a six-week renovation. The gallery will feature works by '
          'local artists and a new interactive exhibit. Museum members may '
          'attend a preview on June 11 from 6:00 to 8:00 P.M. General '
          'admission is \$12, and visitors under 16 enter free when '
          'accompanied by an adult. Tickets can be purchased at the front '
          'desk or through the museum website.',
      prompt: 'Who can attend the preview on June 11?',
      choices: [
        'All visitors who buy a ticket',
        'Local artists only',
        'Museum members',
        'Visitors under 16',
      ],
      correctIndex: 2,
      hint: 'Thông tin về buổi preview nằm ở câu thứ ba.',
    ),
    ExamQuestion(
      number: 10,
      part: 7,
      passage:
          'RIVERSIDE ART MUSEUM\n'
          'Visitor Information\n\n'
          'The Riverside Art Museum will reopen its east gallery on June 12 '
          'after a six-week renovation. The gallery will feature works by '
          'local artists and a new interactive exhibit. Museum members may '
          'attend a preview on June 11 from 6:00 to 8:00 P.M. General '
          'admission is \$12, and visitors under 16 enter free when '
          'accompanied by an adult. Tickets can be purchased at the front '
          'desk or through the museum website.',
      prompt: 'How much is general admission?',
      choices: ['\$8', '\$10', '\$12', '\$16'],
      correctIndex: 2,
      hint: 'Tìm mức giá trong phần Visitor Information.',
    ),
  ],
);
