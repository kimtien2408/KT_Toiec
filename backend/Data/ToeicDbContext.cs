using Abp.EntityFrameworkCore;
using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Data;

public sealed class ToeicDbContext(DbContextOptions<ToeicDbContext> options)
    : AbpDbContext(options)
{
    public DbSet<Exam> Exams => Set<Exam>();
    public DbSet<ExamSession> ExamSessions => Set<ExamSession>();
    public DbSet<Passage> Passages => Set<Passage>();
    public DbSet<Question> Questions => Set<Question>();
    public DbSet<ExamAttempt> ExamAttempts => Set<ExamAttempt>();
    public DbSet<AttemptAnswer> AttemptAnswers => Set<AttemptAnswer>();
    public DbSet<StudentClass> StudentClasses => Set<StudentClass>();
    public DbSet<Student> Students => Set<Student>();
    public DbSet<StaffAccount> StaffAccounts => Set<StaffAccount>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Exam>(entity =>
        {
            entity.ToTable("ToeicExams");
            entity.Property(exam => exam.Title).HasMaxLength(200).IsRequired();
            entity.Property(exam => exam.IsSessionActive).HasDefaultValue(false);
            entity.Property(exam => exam.SessionShift).HasMaxLength(16).HasDefaultValue("Morning");
            entity.Property(exam => exam.SessionCode).HasMaxLength(30);
            entity.HasMany(exam => exam.Questions)
                .WithOne(question => question.Exam)
                .HasForeignKey(question => question.ExamId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(exam => exam.Passages)
                .WithOne(passage => passage.Exam)
                .HasForeignKey(passage => passage.ExamId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(exam => exam.Sessions)
                .WithOne(session => session.Exam)
                .HasForeignKey(session => session.ExamId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ExamSession>(entity =>
        {
            entity.ToTable("ToeicExamSessions");
            entity.Property(session => session.Shift).HasMaxLength(16).IsRequired();
            entity.Property(session => session.SessionCode).HasMaxLength(30);
            entity.HasMany(session => session.Attempts)
                .WithOne(attempt => attempt.ExamSession)
                .HasForeignKey(attempt => attempt.ExamSessionId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Passage>(entity =>
        {
            entity.ToTable("ToeicPassages");
            entity.Property(passage => passage.Content).IsRequired();
            entity.HasMany(passage => passage.Questions)
                .WithOne(question => question.Passage)
                .HasForeignKey(question => question.PassageId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Question>(entity =>
        {
            entity.ToTable("ToeicQuestions");
            entity.Property(question => question.Prompt).IsRequired();
            entity.Property(question => question.ChoiceA).IsRequired();
            entity.Property(question => question.ChoiceB).IsRequired();
            entity.Property(question => question.ChoiceC).IsRequired();
            entity.Property(question => question.ChoiceD).IsRequired();
            entity.HasIndex(question => new { question.ExamId, question.Number })
                .IsUnique();
        });

        modelBuilder.Entity<ExamAttempt>()
            .ToTable("ToeicExamAttempts")
            .HasMany(attempt => attempt.Answers)
            .WithOne(answer => answer.Attempt)
            .HasForeignKey(answer => answer.AttemptId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<AttemptAnswer>()
            .ToTable("ToeicAttemptAnswers")
            .HasOne(answer => answer.Question)
            .WithMany()
            .HasForeignKey(answer => answer.QuestionId)
            .OnDelete(DeleteBehavior.NoAction);

        modelBuilder.Entity<StudentClass>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Code).HasMaxLength(30).IsRequired();
            entity.Property(item => item.AcademicYear).HasMaxLength(30);
            entity.HasIndex(item => item.Code).IsUnique();
            entity.HasMany(item => item.Students)
                .WithOne(student => student.Class)
                .HasForeignKey(student => student.ClassId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Student>(entity =>
        {
            entity.Property(student => student.StudentCode).HasMaxLength(30).IsRequired();
            entity.Property(student => student.FullName).HasMaxLength(120).IsRequired();
            entity.Property(student => student.Email).HasMaxLength(254);
            entity.HasIndex(student => new { student.ClassId, student.StudentCode })
                .IsUnique();
        });

        modelBuilder.Entity<StaffAccount>(entity =>
        {
            entity.ToTable("ToeicStaffAccounts");
            entity.Property(account => account.UserName).HasMaxLength(64).IsRequired();
            entity.Property(account => account.NormalizedUserName).HasMaxLength(64).IsRequired();
            entity.Property(account => account.DisplayName).HasMaxLength(120).IsRequired();
            entity.Property(account => account.Role).HasMaxLength(32).IsRequired();
            entity.Property(account => account.PasswordHash).HasMaxLength(512).IsRequired();
            entity.HasIndex(account => account.NormalizedUserName).IsUnique();
        });

        SeedSampleExam(modelBuilder);
    }

    private static void SeedSampleExam(ModelBuilder modelBuilder)
    {
        var examId = Guid.Parse("c5762312-3f6b-46d0-8f96-4ab270837001");
        var part6PassageId = Guid.Parse("c5762312-3f6b-46d0-8f96-4ab270837006");
        var part7PassageId = Guid.Parse("c5762312-3f6b-46d0-8f96-4ab270837007");
        var questions = new[]
        {
            new QuestionSeed(1, 5, "All employees must submit _____ travel receipts by Friday.", "they", "their", "theirs", "them", 1),
            new QuestionSeed(2, 5, "The new conference room is _____ than the previous one.", "spacious", "more spacious", "most spacious", "spaciously", 1),
            new QuestionSeed(3, 5, "Ms. Kim will contact you as soon as the schedule _____.", "finalizes", "will finalize", "is finalized", "finalizing", 2),
            new QuestionSeed(4, 5, "The package was delivered _____ than we had expected.", "early", "earliest", "earlier", "more early", 2),
            new QuestionSeed(5, 6, "The main office will _____ at 8:30 A.M.", "open", "opens", "opened", "opening", 0, part6PassageId),
            new QuestionSeed(6, 6, "Who should employees contact for early access?", "The office director", "The building manager", "Human Resources", "A visitor services agent", 1, part6PassageId),
            new QuestionSeed(7, 6, "What is one goal of the updated schedule?", "Hire more employees", "Reduce energy use", "Move the main office", "Shorten appointments", 1, part6PassageId),
            new QuestionSeed(8, 7, "When will the east gallery reopen to the public?", "June 11", "June 12", "June 16", "June 21", 1, part7PassageId),
            new QuestionSeed(9, 7, "Who can attend the preview on June 11?", "All ticket holders", "Local artists only", "Museum members", "Visitors under 16", 2, part7PassageId),
            new QuestionSeed(10, 7, "How much is general admission?", "$8", "$10", "$12", "$16", 2, part7PassageId),
        };

        modelBuilder.Entity<Exam>().HasData(new
        {
            Id = examId,
            Title = "TOEIC Reading - Đề luyện tập",
            DurationMinutes = 75,
            IsPublished = true,
            IsSessionActive = true,
            CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
        });
        modelBuilder.Entity<ExamSession>().HasData(new
        {
            Id = Guid.Parse("c5762312-3f6b-46d0-8f96-4ab270837008"),
            ExamId = examId,
            Shift = "Morning",
            SessionDate = new DateTime(2026, 10, 20),
            SessionStart = new TimeSpan(8, 0, 0),
            SessionEnd = new TimeSpan(9, 15, 0),
            SessionCode = (string?)null,
        });
        modelBuilder.Entity<Passage>().HasData(
            new
            {
                Id = part6PassageId,
                ExamId = examId,
                Part = 6,
                Content = "To: All staff\nFrom: Human Resources\nSubject: Updated office hours\n\nBeginning next Monday, the main office will open at 8:30 A.M. Employees who need access before that time should contact the building manager. The updated schedule is intended to reduce energy use while still providing convenient service to visitors.",
            },
            new
            {
                Id = part7PassageId,
                ExamId = examId,
                Part = 7,
                Content = "RIVERSIDE ART MUSEUM\nVisitor Information\n\nThe Riverside Art Museum will reopen its east gallery on June 12 after a six-week renovation. The gallery will feature works by local artists and a new interactive exhibit. Museum members may attend a preview on June 11 from 6:00 to 8:00 P.M. General admission is $12, and visitors under 16 enter free when accompanied by an adult. Tickets can be purchased at the front desk or through the museum website.",
            });
        modelBuilder.Entity<Question>().HasData(questions.Select((question, index) =>
            new Question
            {
                Id = Guid.Parse($"c5762312-3f6b-46d0-8f96-4ab2708370{index + 2:D2}"),
                ExamId = examId,
                PassageId = question.PassageId,
                Number = question.Number,
                Part = question.Part,
                Prompt = question.Prompt,
                ChoiceA = question.ChoiceA,
                ChoiceB = question.ChoiceB,
                ChoiceC = question.ChoiceC,
                ChoiceD = question.ChoiceD,
                CorrectAnswerIndex = question.CorrectAnswerIndex,
            }));
    }

    private sealed record QuestionSeed(
        int Number,
        int Part,
        string Prompt,
        string ChoiceA,
        string ChoiceB,
        string ChoiceC,
        string ChoiceD,
        int CorrectAnswerIndex,
        Guid? PassageId = null);
}
