using Abp.Web.Models;
using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[DontWrapResult]
[Route("api/exams")]
public sealed class ExamsController(ToeicDbContext database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ExamSummaryDto>>> GetPublishedExams(
        CancellationToken cancellationToken)
    {
        var exams = await database.Exams
            .AsNoTracking()
            .Where(exam => exam.IsPublished
                && exam.IsSessionActive
                && exam.Sessions.Any(session =>
                    session.SessionDate != null
                    && session.SessionStart != null
                    && session.SessionEnd > session.SessionStart))
            .OrderByDescending(exam => exam.CreatedAt)
            .Select(exam => new ExamSummaryDto(
                exam.Id,
                exam.Title,
                exam.DurationMinutes,
                exam.Questions.Count,
                exam.Sessions
                    .Where(session => session.SessionDate != null
                        && session.SessionStart != null
                        && session.SessionEnd > session.SessionStart)
                    .OrderBy(session => session.SessionDate)
                    .ThenBy(session => session.SessionStart)
                    .Select(session => new ExamSessionDto(
                        session.Id,
                        session.Shift,
                        session.SessionDate,
                        session.SessionStart,
                        session.SessionEnd,
                        !string.IsNullOrWhiteSpace(session.SessionCode)))
                    .ToList()))
            .ToListAsync(cancellationToken);

        return Ok(exams);
    }

    [HttpGet("{examId:guid}")]
    public async Task<ActionResult<ExamDetailDto>> GetExam(
        Guid examId,
        CancellationToken cancellationToken)
    {
        var exam = await database.Exams
            .AsNoTracking()
            .Where(item => item.Id == examId
                && item.IsPublished
                && item.IsSessionActive
                && item.Sessions.Any(session =>
                    session.SessionDate != null
                    && session.SessionStart != null
                    && session.SessionEnd > session.SessionStart))
            .Select(item => new ExamDetailDto(
                item.Id,
                item.Title,
                item.DurationMinutes,
                item.Questions.OrderBy(question => question.Number)
                    .Select(question => new ExamQuestionDto(
                        question.Id,
                        question.Number,
                        question.Part,
                        question.Prompt,
                        new[]
                        {
                            question.ChoiceA,
                            question.ChoiceB,
                            question.ChoiceC,
                            question.ChoiceD,
                        },
                        question.Passage == null ? null : question.Passage.Content))
                    .ToList()))
            .SingleOrDefaultAsync(cancellationToken);

        return exam is null ? NotFound() : Ok(exam);
    }

    [HttpPost("{examId:guid}/sessions/{sessionId:guid}/validate")]
    public async Task<ActionResult<SessionCodeValidationDto>> ValidateSessionCode(
        Guid examId,
        Guid sessionId,
        ValidateSessionCodeRequest request,
        CancellationToken cancellationToken)
    {
        var session = await database.ExamSessions
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.Id == sessionId
                    && item.ExamId == examId
                    && item.Exam.IsPublished
                    && item.Exam.IsSessionActive
                    && item.SessionDate != null
                    && item.SessionStart != null
                    && item.SessionEnd > item.SessionStart,
                cancellationToken);
        if (session is null)
        {
            return NotFound();
        }

        var hasCode = !string.IsNullOrWhiteSpace(session.SessionCode);
        var isValid = !hasCode
            || string.Equals(session.SessionCode, request.Code?.Trim(), StringComparison.OrdinalIgnoreCase);
        return Ok(new SessionCodeValidationDto(
            isValid,
            isValid ? null : "Mã ca thi không chính xác."));
    }

    [HttpPost("{examId:guid}/attempts")]
    public async Task<ActionResult<AttemptResultDto>> SubmitAttempt(
        Guid examId,
        SubmitAttemptRequest request,
        CancellationToken cancellationToken)
    {
        var session = await database.ExamSessions
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.Id == request.SessionId
                    && item.ExamId == examId
                    && item.Exam.IsPublished
                    && item.Exam.IsSessionActive
                    && item.SessionDate != null
                    && item.SessionStart != null
                    && item.SessionEnd > item.SessionStart,
                cancellationToken);
        if (session is null) return NotFound();

        var exam = await database.Exams
            .Include(item => item.Questions)
            .SingleOrDefaultAsync(
                item => item.Id == examId && item.IsPublished && item.IsSessionActive,
                cancellationToken);
        if (exam is null) return NotFound();

        var hasSessionCode = !string.IsNullOrWhiteSpace(session.SessionCode);
        if (hasSessionCode
            && !string.Equals(
                session.SessionCode,
                request.SessionCode?.Trim(),
                StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Mã ca thi không chính xác.",
                Detail = "Vui lòng kiểm tra mã ca thi và nộp lại bài.",
            });
        }

        var suppliedAnswers = request.Answers ?? [];
        if (suppliedAnswers.Any(answer => answer.AnswerIndex is < 0 or > 3)
            || suppliedAnswers.Select(answer => answer.QuestionId).Distinct().Count()
                != suppliedAnswers.Count
            || suppliedAnswers.Any(answer =>
                exam.Questions.All(question => question.Id != answer.QuestionId)))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Câu trả lời không hợp lệ.",
                Detail = "Mỗi câu chỉ được gửi một đáp án từ A đến D và phải thuộc đề thi.",
            });
        }

        var selectedByQuestion = suppliedAnswers.ToDictionary(
            answer => answer.QuestionId,
            answer => answer.AnswerIndex);
        var attempt = new ExamAttempt
        {
            Id = Guid.NewGuid(),
            ExamId = exam.Id,
            ExamSessionId = session.Id,
            SubmittedAt = DateTime.UtcNow,
        };
        foreach (var question in exam.Questions)
        {
            selectedByQuestion.TryGetValue(question.Id, out var selectedIndex);
            var hasAnswer = selectedByQuestion.ContainsKey(question.Id);
            attempt.Answers.Add(new AttemptAnswer
            {
                Id = Guid.NewGuid(),
                AttemptId = attempt.Id,
                QuestionId = question.Id,
                SelectedAnswerIndex = hasAnswer ? selectedIndex : null,
                IsCorrect = hasAnswer && selectedIndex == question.CorrectAnswerIndex,
            });
        }

        database.ExamAttempts.Add(attempt);
        await database.SaveChangesAsync(cancellationToken);

        var correctCount = attempt.Answers.Count(answer => answer.IsCorrect);
        var unansweredCount = attempt.Answers.Count(answer =>
            answer.SelectedAnswerIndex is null);
        var answerReviews = exam.Questions
            .OrderBy(question => question.Number)
            .Select(question =>
            {
                var selectedIndex = selectedByQuestion.TryGetValue(
                    question.Id,
                    out var answerIndex)
                    ? answerIndex
                    : (int?)null;
                return new AttemptAnswerReviewDto(
                    question.Id,
                    selectedIndex,
                    question.CorrectAnswerIndex,
                    question.Hint);
            })
            .ToList();
        return Ok(new AttemptResultDto(
            attempt.Id,
            exam.Questions.Count,
            correctCount,
            exam.Questions.Count - correctCount - unansweredCount,
            unansweredCount,
            attempt.SubmittedAt,
            answerReviews));
    }
}

public sealed record ExamSummaryDto(
    Guid Id,
    string Title,
    int DurationMinutes,
    int QuestionCount,
    IReadOnlyList<ExamSessionDto> Sessions);

public sealed record ExamSessionDto(
    Guid Id,
    string Shift,
    DateTime? SessionDate,
    TimeSpan? SessionStart,
    TimeSpan? SessionEnd,
    bool RequiresSessionCode);

public sealed record ExamDetailDto(
    Guid Id,
    string Title,
    int DurationMinutes,
    IReadOnlyList<ExamQuestionDto> Questions);

public sealed record ExamQuestionDto(
    Guid Id,
    int Number,
    int Part,
    string Prompt,
    IReadOnlyList<string> Choices,
    string? Passage);

public sealed record SubmitAttemptRequest(
    Guid SessionId,
    IReadOnlyList<SubmittedAnswer>? Answers,
    string? SessionCode);
public sealed record SubmittedAnswer(Guid QuestionId, int AnswerIndex);
public sealed record ValidateSessionCodeRequest(string? Code);
public sealed record SessionCodeValidationDto(bool IsValid, string? Message);
public sealed record AttemptResultDto(
    Guid AttemptId,
    int TotalQuestions,
    int Correct,
    int Incorrect,
    int Unanswered,
    DateTime SubmittedAt,
    IReadOnlyList<AttemptAnswerReviewDto> Answers);

public sealed record AttemptAnswerReviewDto(
    Guid QuestionId,
    int? SelectedAnswerIndex,
    int CorrectAnswerIndex,
    string? Hint);
