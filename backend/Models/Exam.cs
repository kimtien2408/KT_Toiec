namespace backend.Models;

public sealed class Exam
{
    public Guid Id { get; set; }
    public required string Title { get; set; }
    public int DurationMinutes { get; set; } = 75;
    public bool IsPublished { get; set; }
    public bool IsSessionActive { get; set; }
    public string SessionShift { get; set; } = "Morning";
    public DateTime? SessionDate { get; set; }
    public TimeSpan? SessionStart { get; set; }
    public TimeSpan? SessionEnd { get; set; }
    public string? SessionCode { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public ICollection<Passage> Passages { get; set; } = [];
    public ICollection<Question> Questions { get; set; } = [];
    public ICollection<ExamAttempt> Attempts { get; set; } = [];
    public ICollection<ExamSession> Sessions { get; set; } = [];
}

public sealed class ExamSession
{
    public Guid Id { get; set; }
    public Guid ExamId { get; set; }
    public string Shift { get; set; } = "Morning";
    public DateTime? SessionDate { get; set; }
    public TimeSpan? SessionStart { get; set; }
    public TimeSpan? SessionEnd { get; set; }
    public string? SessionCode { get; set; }
    public Exam Exam { get; set; } = null!;
    public ICollection<ExamAttempt> Attempts { get; set; } = [];
}

public sealed class Passage
{
    public Guid Id { get; set; }
    public Guid ExamId { get; set; }
    public int Part { get; set; }
    public required string Content { get; set; }
    public Exam Exam { get; set; } = null!;
    public ICollection<Question> Questions { get; set; } = [];
}

public sealed class Question
{
    public Guid Id { get; set; }
    public Guid ExamId { get; set; }
    public Guid? PassageId { get; set; }
    public int Number { get; set; }
    public int Part { get; set; }
    public required string Prompt { get; set; }
    public required string ChoiceA { get; set; }
    public required string ChoiceB { get; set; }
    public required string ChoiceC { get; set; }
    public required string ChoiceD { get; set; }
    public int CorrectAnswerIndex { get; set; }
    public string? Hint { get; set; }
    public Exam Exam { get; set; } = null!;
    public Passage? Passage { get; set; }
}

public sealed class ExamAttempt
{
    public Guid Id { get; set; }
    public Guid ExamId { get; set; }
    public Guid? ExamSessionId { get; set; }
    public DateTime SubmittedAt { get; set; } = DateTime.UtcNow;
    public Exam Exam { get; set; } = null!;
    public ExamSession? ExamSession { get; set; }
    public ICollection<AttemptAnswer> Answers { get; set; } = [];
}

public sealed class AttemptAnswer
{
    public Guid Id { get; set; }
    public Guid AttemptId { get; set; }
    public Guid QuestionId { get; set; }
    public int? SelectedAnswerIndex { get; set; }
    public bool IsCorrect { get; set; }
    public ExamAttempt Attempt { get; set; } = null!;
    public Question Question { get; set; } = null!;
}

public sealed class StudentClass
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public required string Code { get; set; }
    public string? AcademicYear { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public ICollection<Student> Students { get; set; } = [];
}

public sealed class Student
{
    public Guid Id { get; set; }
    public Guid ClassId { get; set; }
    public required string StudentCode { get; set; }
    public required string FullName { get; set; }
    public string? Email { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public StudentClass Class { get; set; } = null!;
}
