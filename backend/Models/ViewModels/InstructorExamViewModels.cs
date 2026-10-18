using System.ComponentModel.DataAnnotations;

namespace backend.Models.ViewModels;

public sealed record InstructorExamListItem(
    Guid Id,
    string Title,
    int DurationMinutes,
    bool IsPublished,
    bool IsSessionActive,
    int SessionCount,
    int QuestionCount,
    int AttemptCount,
    DateTime CreatedAt);

public sealed record InstructorDashboardViewModel(
    IReadOnlyList<InstructorExamListItem> Exams,
    int PublishedCount,
    int DraftCount,
    int NeedsReviewCount);

public sealed record InstructorStatisticsViewModel(
    int AttemptCount,
    double AverageAccuracy,
    IReadOnlyList<InstructorQuestionMiss> TopMisses);

public sealed record InstructorQuestionMiss(
    int Number,
    int Part,
    string Prompt,
    int IncorrectCount,
    int AttemptCount);

public sealed record InstructorHomeViewModel(
    int ExamCount,
    int PublishedExamCount,
    int ClassCount,
    int StudentCount);

public sealed record StudentClassListItem(
    Guid Id,
    string Name,
    string Code,
    string? AcademicYear,
    int StudentCount,
    DateTime CreatedAt);

public sealed record StudentClassDetailsViewModel(
    StudentClassListItem Class,
    IReadOnlyList<StudentListItem> Students);

public sealed record StudentListItem(
    Guid Id,
    string StudentCode,
    string FullName,
    string? Email,
    DateTime CreatedAt);

public sealed class CreateStudentClassViewModel
{
    [Required(ErrorMessage = "Vui lòng nhập tên lớp.")]
    [StringLength(120, ErrorMessage = "Tên lớp không được quá 120 ký tự.")]
    [Display(Name = "Tên lớp")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mã lớp.")]
    [StringLength(30, ErrorMessage = "Mã lớp không được quá 30 ký tự.")]
    [RegularExpression(
        @"^[A-Za-z0-9_-]+$",
        ErrorMessage = "Mã lớp chỉ được chứa chữ, số, dấu gạch ngang và gạch dưới.")]
    [Display(Name = "Mã lớp")]
    public string Code { get; set; } = string.Empty;

    [StringLength(30, ErrorMessage = "Năm học không được quá 30 ký tự.")]
    [Display(Name = "Năm học")]
    public string? AcademicYear { get; set; }
}

public sealed class AddStudentViewModel
{
    public Guid ClassId { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập mã sinh viên.")]
    [StringLength(30, ErrorMessage = "Mã sinh viên không được quá 30 ký tự.")]
    [Display(Name = "Mã sinh viên")]
    public string StudentCode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập họ tên sinh viên.")]
    [StringLength(120, ErrorMessage = "Họ tên không được quá 120 ký tự.")]
    [Display(Name = "Họ tên")]
    public string FullName { get; set; } = string.Empty;

    [EmailAddress(ErrorMessage = "Địa chỉ email chưa đúng định dạng.")]
    [StringLength(254, ErrorMessage = "Email không được quá 254 ký tự.")]
    [Display(Name = "Email (không bắt buộc)")]
    public string? Email { get; set; }
}

public sealed class EditExamViewModel
{
    public Guid Id { get; set; }
    public Guid? SelectedQuestionId { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập tên đề thi.")]
    [StringLength(200, ErrorMessage = "Tên đề thi không được vượt quá 200 ký tự.")]
    public string Title { get; set; } = string.Empty;

    [Range(1, 300, ErrorMessage = "Thời gian làm bài phải từ 1 đến 300 phút.")]
    [Display(Name = "Thời gian làm bài (phút)")]
    public int DurationMinutes { get; set; }

    public IReadOnlyList<InstructorExamSessionItem> Sessions { get; set; } = [];

    public bool IsPublished { get; set; }

    public IReadOnlyList<ExamQuestionReviewItem> Questions { get; set; } = [];

    public ExamQuestionReviewItem? SelectedQuestion =>
        Questions.FirstOrDefault(question => question.Id == SelectedQuestionId)
        ?? Questions.FirstOrDefault();

    public IReadOnlyList<IGrouping<int, ExamQuestionReviewItem>> QuestionParts =>
        Questions.GroupBy(question => question.Part).OrderBy(group => group.Key).ToList();

    public IReadOnlyList<string> PublicationIssues
    {
        get
        {
            var issues = new List<string>();
            if (Questions.Count == 0)
            {
                issues.Add("Cần có ít nhất một câu hỏi.");
            }

            var invalidQuestions = Questions
                .Select(question => new
                {
                    question.Number,
                    Issues = GetQuestionIssues(question),
                })
                .Where(item => item.Issues.Count > 0)
                .ToList();
            foreach (var question in invalidQuestions.Take(10))
            {
                issues.Add($"Câu {question.Number}: {string.Join(", ", question.Issues)}.");
            }

            if (invalidQuestions.Count > 10)
            {
                issues.Add($"Còn {invalidQuestions.Count - 10} câu khác cần kiểm tra nội dung.");
            }

            return issues;
        }
    }

    public bool CanPublish => PublicationIssues.Count == 0;

    private static List<string> GetQuestionIssues(ExamQuestionReviewItem question)
    {
        var issues = new List<string>();
        if (question.Part is not (5 or 6 or 7))
        {
            issues.Add("phần thi phải là Part 5, 6 hoặc 7");
        }
        if (question.CorrectAnswerIndex is < 0 or > 3)
        {
            issues.Add("chưa có đáp án đúng hợp lệ");
        }
        if (string.IsNullOrWhiteSpace(question.Prompt))
        {
            issues.Add("thiếu nội dung câu hỏi");
        }
        if (string.IsNullOrWhiteSpace(question.ChoiceA)
            || string.IsNullOrWhiteSpace(question.ChoiceB)
            || string.IsNullOrWhiteSpace(question.ChoiceC)
            || string.IsNullOrWhiteSpace(question.ChoiceD))
        {
            issues.Add("thiếu một hoặc nhiều lựa chọn A-D");
        }
        if (question.Part == 5 && question.PassageId is not null)
        {
            issues.Add("Part 5 không được gắn đoạn đọc");
        }
        else if (question.Part is 6 or 7
            && (question.PassageId is null
                || question.PassagePart != question.Part
                || string.IsNullOrWhiteSpace(question.PassageContent)))
        {
            issues.Add($"thiếu đoạn đọc Part {question.Part} hợp lệ");
        }

        return issues;
    }
}

public sealed record InstructorExamSessionItem(
    Guid Id,
    string Shift,
    DateTime? SessionDate,
    TimeSpan? SessionStart,
    TimeSpan? SessionEnd,
    string? SessionCode,
    int AttemptCount);

public sealed class EditExamSessionViewModel
{
    public Guid Id { get; set; }

    [RegularExpression("^(Morning|Afternoon)$", ErrorMessage = "Vui lòng chọn ca sáng hoặc ca chiều.")]
    public string Shift { get; set; } = "Morning";

    public DateTime? SessionDate { get; set; }

    public TimeSpan? SessionStart { get; set; }

    public TimeSpan? SessionEnd { get; set; }

    [StringLength(30, ErrorMessage = "Mã ca thi không được quá 30 ký tự.")]
    public string? SessionCode { get; set; }

    public int AttemptCount { get; set; }
}

public sealed record ExamQuestionReviewItem(
    Guid Id,
    int Number,
    int Part,
    string Prompt,
    string ChoiceA,
    string ChoiceB,
    string ChoiceC,
    string ChoiceD,
    int CorrectAnswerIndex,
    string? Hint,
    Guid? PassageId,
    int? PassagePart,
    string? PassageContent);

public sealed class EditExamQuestionViewModel
{
    [Required]
    public Guid ExamId { get; set; }

    [Required]
    public Guid QuestionId { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập nội dung câu hỏi.")]
    [StringLength(4000, ErrorMessage = "Nội dung câu hỏi không được vượt quá 4000 ký tự.")]
    public string Prompt { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập đáp án A.")]
    [StringLength(1000, ErrorMessage = "Mỗi đáp án không được vượt quá 1000 ký tự.")]
    public string ChoiceA { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập đáp án B.")]
    [StringLength(1000, ErrorMessage = "Mỗi đáp án không được vượt quá 1000 ký tự.")]
    public string ChoiceB { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập đáp án C.")]
    [StringLength(1000, ErrorMessage = "Mỗi đáp án không được vượt quá 1000 ký tự.")]
    public string ChoiceC { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập đáp án D.")]
    [StringLength(1000, ErrorMessage = "Mỗi đáp án không được vượt quá 1000 ký tự.")]
    public string ChoiceD { get; set; } = string.Empty;

    [Range(0, 3, ErrorMessage = "Vui lòng chọn một đáp án đúng.")]
    public int CorrectAnswerIndex { get; set; }

    [StringLength(4000, ErrorMessage = "Phần giải thích không được vượt quá 4000 ký tự.")]
    public string? Hint { get; set; }
}

public sealed class EditExamPassageViewModel
{
    [Required]
    public Guid ExamId { get; set; }

    [Required]
    public Guid PassageId { get; set; }

    public Guid? SelectedQuestionId { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập nội dung đoạn đọc.")]
    [StringLength(20000, ErrorMessage = "Nội dung đoạn đọc không được vượt quá 20000 ký tự.")]
    public string Content { get; set; } = string.Empty;
}

public sealed class ImportExamViewModel
{
    public int CurrentStep { get; set; } = 1;

    [Display(Name = "Tên đề thi")]
    public string? Title { get; set; }

    [Display(Name = "Tài liệu DOCX")]
    public IFormFile? File { get; set; }

    public IReadOnlyList<string> Errors { get; set; } = [];
}
