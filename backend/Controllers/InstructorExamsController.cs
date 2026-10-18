using backend.Data;
using backend.Models;
using backend.Models.ViewModels;
using backend.Services;
using Abp.Runtime.Validation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[Route("instructor/exams")]
[Authorize(Roles = StaffRoles.Admin + "," + StaffRoles.Instructor)]
public sealed class InstructorExamsController(
    ToeicDbContext database,
    ExamDocxParser docxParser) : Controller
{
    [HttpGet("/")]
    public async Task<IActionResult> Home(CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "home";
        var model = new InstructorHomeViewModel(
            await database.Exams.CountAsync(cancellationToken),
            await database.Exams.CountAsync(exam => exam.IsPublished, cancellationToken),
            await database.StudentClasses.CountAsync(cancellationToken),
            await database.Students.CountAsync(cancellationToken));

        return View(model);
    }

    [HttpGet("")]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "exams";
        var exams = await database.Exams
            .AsNoTracking()
            .OrderByDescending(exam => exam.CreatedAt)
            .Select(exam => new InstructorExamListItem(
                exam.Id,
                exam.Title,
                exam.DurationMinutes,
                exam.IsPublished,
                exam.IsSessionActive,
                exam.Sessions.Count(session =>
                    session.SessionDate != null
                    && session.SessionStart != null
                    && session.SessionEnd > session.SessionStart),
                exam.Questions.Count,
                exam.Attempts.Count,
                exam.CreatedAt))
            .ToListAsync(cancellationToken);

        return View(new InstructorDashboardViewModel(
            exams,
            exams.Count(exam => exam.IsPublished),
            exams.Count(exam => !exam.IsPublished),
            exams.Count(exam => exam.QuestionCount == 0)));
    }

    [HttpPost("{id:guid}/delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteDraft(
        Guid id,
        CancellationToken cancellationToken)
    {
        await using var transaction = await database.Database.BeginTransactionAsync(
            System.Data.IsolationLevel.Serializable,
            cancellationToken);
        var exam = await database.Exams
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null)
        {
            return NotFound();
        }
        if (exam.IsPublished)
        {
            TempData["StatusMessage"] = "Không thể xóa đề đã xuất bản. Hãy chuyển đề về bản nháp trước.";
            return RedirectToAction(nameof(Index));
        }
        if (await database.ExamAttempts.AnyAsync(
                attempt => attempt.ExamId == id,
                cancellationToken))
        {
            TempData["StatusMessage"] = "Không thể xóa bản nháp đã có lượt thi.";
            return RedirectToAction(nameof(Index));
        }

        database.Questions.RemoveRange(
            database.Questions.Where(question => question.ExamId == id));
        database.Passages.RemoveRange(
            database.Passages.Where(passage => passage.ExamId == id));
        database.ExamSessions.RemoveRange(
            database.ExamSessions.Where(session => session.ExamId == id));
        database.Exams.Remove(exam);
        await database.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        TempData["StatusMessage"] = $"Đã xóa bản nháp “{exam.Title}”.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet("import")]
    public IActionResult Import([FromQuery] int step = 1)
    {
        ViewData["ActiveNav"] = "exams";
        return View(new ImportExamViewModel
        {
            CurrentStep = Math.Clamp(step, 1, 2),
        });
    }

    [HttpPost("import")]
    [ValidateAntiForgeryToken]
    [DisableValidation]
    [RequestSizeLimit(ExamDocxParser.MaximumFileSize + 1024 * 1024)]
    public async Task<IActionResult> Import(
        ImportExamViewModel model,
        CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "exams";
        model.CurrentStep = 2;
        var title = model.Title?.Trim() ?? string.Empty;
        model.Title = title;
        if (title.Length == 0)
        {
            ModelState.AddModelError(nameof(model.Title), "Vui lòng nhập tên đề thi.");
        }
        else if (title.Length > 200)
        {
            ModelState.AddModelError(
                nameof(model.Title),
                "Tên đề thi không được vượt quá 200 ký tự.");
        }
        if (model.File is null)
        {
            ModelState.AddModelError(nameof(model.File), "Vui lòng chọn file DOCX.");
        }
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var file = model.File!;
        if (!string.Equals(Path.GetExtension(file.FileName), ".docx", StringComparison.OrdinalIgnoreCase))
        {
            ModelState.AddModelError(nameof(model.File), "Chỉ hỗ trợ tài liệu .docx.");
            return View(model);
        }
        if (file.Length == 0)
        {
            ModelState.AddModelError(nameof(model.File), "Tệp DOCX đang trống.");
            return View(model);
        }
        if (file.Length > ExamDocxParser.MaximumFileSize)
        {
            ModelState.AddModelError(nameof(model.File), "Tệp vượt quá giới hạn 20 MB.");
            return View(model);
        }

        await using var stream = file.OpenReadStream();
        var parseResult = docxParser.Parse(stream);
        if (!parseResult.IsValid)
        {
            model.Errors = parseResult.Errors;
            return View(model);
        }

        var exam = new Exam
        {
            Id = Guid.NewGuid(),
            Title = title,
            DurationMinutes = 75,
            IsPublished = false,
        };
        var passageEntities = new Dictionary<ParsedExamPassage, Passage>(
            ReferenceEqualityComparer.Instance);
        foreach (var parsedPassage in parseResult.Passages)
        {
            var passage = new Passage
            {
                Id = Guid.NewGuid(),
                ExamId = exam.Id,
                Part = parsedPassage.Part,
                Content = parsedPassage.Content,
                Exam = exam,
            };
            passageEntities.Add(parsedPassage, passage);
            database.Passages.Add(passage);
        }

        foreach (var parsedQuestion in parseResult.Questions)
        {
            var passage = parsedQuestion.Passage is not null
                ? passageEntities[parsedQuestion.Passage]
                : null;
            database.Questions.Add(new Question
            {
                Id = Guid.NewGuid(),
                ExamId = exam.Id,
                PassageId = passage?.Id,
                Part = parsedQuestion.Part,
                Number = parsedQuestion.Number,
                Prompt = parsedQuestion.Prompt,
                ChoiceA = parsedQuestion.Choices[0],
                ChoiceB = parsedQuestion.Choices[1],
                ChoiceC = parsedQuestion.Choices[2],
                ChoiceD = parsedQuestion.Choices[3],
                CorrectAnswerIndex = parsedQuestion.CorrectAnswerIndex,
                Hint = parsedQuestion.Hint,
                Exam = exam,
                Passage = passage,
            });
        }

        database.Exams.Add(exam);
        await using var transaction = await database.Database.BeginTransactionAsync(cancellationToken);
        await database.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        TempData["StatusMessage"] = "Đã kiểm tra và lưu đề ở trạng thái bản nháp. Hãy chỉnh sửa nội dung trước khi xuất bản.";
        return RedirectToAction(nameof(Edit), new { id = exam.Id });
    }

    [HttpGet("/instructor/statistics")]
    public async Task<IActionResult> Statistics(CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "statistics";
        var answerRows = await database.AttemptAnswers
            .AsNoTracking()
            .Select(answer => new { answer.AttemptId, answer.IsCorrect })
            .ToListAsync(cancellationToken);
        var attemptScores = answerRows
            .GroupBy(answer => answer.AttemptId)
            .Select(answers => answers.ToList())
            .ToList();

        var averageAccuracy = attemptScores.Count == 0
            ? 0
            : attemptScores.Average(answers => answers.Count == 0
                ? 0
                : answers.Count(answer => answer.IsCorrect) * 100d / answers.Count);

        var examAttemptCounts = (await database.ExamAttempts
            .AsNoTracking()
            .GroupBy(attempt => attempt.ExamId)
            .Select(group => new { ExamId = group.Key, Count = group.Count() })
            .ToListAsync(cancellationToken))
            .ToDictionary(item => item.ExamId, item => item.Count);

        var incorrectAnswers = await database.AttemptAnswers
            .AsNoTracking()
            .Where(answer => !answer.IsCorrect)
            .Select(answer => new
            {
                answer.Question.ExamId,
                answer.Question.Number,
                answer.Question.Part,
                answer.Question.Prompt,
            })
            .ToListAsync(cancellationToken);

        var topMisses = incorrectAnswers
            .GroupBy(answer => new
            {
                answer.ExamId,
                answer.Number,
                answer.Part,
                answer.Prompt,
            })
            .Select(group => new InstructorQuestionMiss(
                group.Key.Number,
                group.Key.Part,
                group.Key.Prompt,
                group.Count(),
                examAttemptCounts[group.Key.ExamId]))
            .OrderByDescending(question => question.IncorrectCount)
            .ThenBy(question => question.Number)
            .Take(10)
            .ToList();

        return View(new InstructorStatisticsViewModel(
            attemptScores.Count,
            Math.Round(averageAccuracy, 1),
            topMisses));
    }

    [HttpGet("{id:guid}/edit")]
    public async Task<IActionResult> Edit(
        Guid id,
        [FromQuery] Guid? questionId,
        CancellationToken cancellationToken)
    {
        var exam = await database.Exams
            .AsNoTracking()
            .Include(item => item.Questions)
                .ThenInclude(question => question.Passage)
            .Include(item => item.Sessions)
                .ThenInclude(session => session.Attempts)
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null)
        {
            return NotFound();
        }

        var model = new EditExamViewModel
        {
            Id = exam.Id,
            SelectedQuestionId = questionId,
            Title = exam.Title,
            DurationMinutes = exam.DurationMinutes,
            IsPublished = exam.IsPublished,
            Sessions = exam.Sessions
                .OrderBy(session => session.SessionDate)
                .ThenBy(session => session.SessionStart)
                .Select(session => new InstructorExamSessionItem(
                    session.Id,
                    session.Shift,
                    session.SessionDate,
                    session.SessionStart,
                    session.SessionEnd,
                    session.SessionCode,
                    session.Attempts.Count))
                .ToList(),
            Questions = BuildReviewItems(exam.Questions),
        };

        return View(model);
    }

    [HttpPost("{id:guid}/edit")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(
        Guid id,
        EditExamViewModel model,
        CancellationToken cancellationToken)
    {
        if (id != model.Id)
        {
            return BadRequest();
        }

        model.Title = model.Title?.Trim() ?? string.Empty;
        var exam = await database.Exams
            .Include(item => item.Questions)
                .ThenInclude(question => question.Passage)
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null)
        {
            return NotFound();
        }
        model.Questions = BuildReviewItems(exam.Questions);
        if (model.SelectedQuestionId is null
            || model.Questions.All(question => question.Id != model.SelectedQuestionId))
        {
            model.SelectedQuestionId = model.Questions.FirstOrDefault()?.Id;
        }
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        exam.Title = model.Title;
        exam.DurationMinutes = model.DurationMinutes;
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đã cập nhật đề thi.";

        return RedirectToAction(nameof(Edit), new { id, questionId = model.SelectedQuestionId });
    }

    [HttpPost("{id:guid}/sessions")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddSession(
        Guid id,
        EditExamSessionViewModel model,
        CancellationToken cancellationToken)
    {
        var exam = await database.Exams
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null) return NotFound();

        NormalizeAndValidateSession(model);
        if (!ModelState.IsValid)
        {
            TempData["StatusMessage"] = "Không thể thêm ca thi. Kiểm tra lại ngày, giờ và mã ca.";
            return RedirectToAction(nameof(Edit), new { id });
        }

        database.ExamSessions.Add(new ExamSession
        {
            Id = Guid.NewGuid(),
            ExamId = id,
            Shift = model.Shift,
            SessionDate = model.SessionDate?.Date,
            SessionStart = model.SessionStart,
            SessionEnd = model.SessionEnd,
            SessionCode = model.SessionCode,
        });
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đã thêm ca thi.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost("{id:guid}/sessions/{sessionId:guid}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateSession(
        Guid id,
        Guid sessionId,
        EditExamSessionViewModel model,
        CancellationToken cancellationToken)
    {
        var session = await database.ExamSessions
            .Include(item => item.Attempts)
            .SingleOrDefaultAsync(
                item => item.Id == sessionId && item.ExamId == id,
                cancellationToken);
        if (session is null) return NotFound();
        if (session.Attempts.Count > 0)
        {
            TempData["StatusMessage"] = "Không thể chỉnh sửa ca đã có lượt thi.";
            return RedirectToAction(nameof(Edit), new { id });
        }

        NormalizeAndValidateSession(model);
        if (!ModelState.IsValid)
        {
            TempData["StatusMessage"] = "Không thể cập nhật ca thi. Kiểm tra lại ngày, giờ và mã ca.";
            return RedirectToAction(nameof(Edit), new { id });
        }

        session.Shift = model.Shift;
        session.SessionDate = model.SessionDate?.Date;
        session.SessionStart = model.SessionStart;
        session.SessionEnd = model.SessionEnd;
        session.SessionCode = model.SessionCode;
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đã cập nhật ca thi.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost("{id:guid}/sessions/{sessionId:guid}/delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteSession(
        Guid id,
        Guid sessionId,
        CancellationToken cancellationToken)
    {
        var session = await database.ExamSessions
            .Include(item => item.Attempts)
            .SingleOrDefaultAsync(
                item => item.Id == sessionId && item.ExamId == id,
                cancellationToken);
        if (session is null) return NotFound();
        if (session.Attempts.Count > 0)
        {
            TempData["StatusMessage"] = "Không thể xóa ca đã có lượt thi.";
            return RedirectToAction(nameof(Edit), new { id });
        }

        database.ExamSessions.Remove(session);
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đã xóa ca thi.";
        return RedirectToAction(nameof(Edit), new { id });
    }

    private void NormalizeAndValidateSession(EditExamSessionViewModel model)
    {
        model.SessionCode = string.IsNullOrWhiteSpace(model.SessionCode)
            ? null
            : model.SessionCode.Trim();
        if (model.SessionDate is null)
        {
            ModelState.AddModelError(nameof(model.SessionDate), "Vui lòng chọn ngày tổ chức.");
        }
        if (model.SessionStart is null || model.SessionEnd is null
            || model.SessionEnd <= model.SessionStart)
        {
            ModelState.AddModelError(nameof(model.SessionEnd), "Giờ kết thúc phải sau giờ bắt đầu.");
        }
        if (model.SessionStart is TimeSpan start
            && (start < TimeSpan.Zero || start >= TimeSpan.FromDays(1))
            || model.SessionEnd is TimeSpan end
            && (end < TimeSpan.Zero || end >= TimeSpan.FromDays(1)))
        {
            ModelState.AddModelError(nameof(model.SessionStart), "Giờ thi phải nằm trong khoảng 00:00 đến 23:59.");
        }
        TryValidateModel(model);
    }

    [HttpPost("{id:guid}/questions/{questionId:guid}")]
    [ValidateAntiForgeryToken]
    [DisableValidation]
    public async Task<IActionResult> EditQuestion(
        Guid id,
        Guid questionId,
        EditExamQuestionViewModel model,
        CancellationToken cancellationToken)
    {
        if (model.ExamId != id || model.QuestionId != questionId)
        {
            return BadRequest();
        }

        model.Prompt = model.Prompt?.Trim() ?? string.Empty;
        model.ChoiceA = model.ChoiceA?.Trim() ?? string.Empty;
        model.ChoiceB = model.ChoiceB?.Trim() ?? string.Empty;
        model.ChoiceC = model.ChoiceC?.Trim() ?? string.Empty;
        model.ChoiceD = model.ChoiceD?.Trim() ?? string.Empty;
        model.Hint = string.IsNullOrWhiteSpace(model.Hint) ? null : model.Hint.Trim();
        TryValidateModel(model);
        if (!ModelState.IsValid)
        {
            TempData["StatusMessage"] = "Không lưu được câu hỏi. Kiểm tra lại nội dung và đáp án.";
            return RedirectToAction(nameof(Edit), new { id, questionId });
        }

        var question = await database.Questions
            .SingleOrDefaultAsync(
                item => item.Id == questionId && item.ExamId == id,
                cancellationToken);
        if (question is null)
        {
            return NotFound();
        }

        question.Prompt = model.Prompt;
        question.ChoiceA = model.ChoiceA;
        question.ChoiceB = model.ChoiceB;
        question.ChoiceC = model.ChoiceC;
        question.ChoiceD = model.ChoiceD;
        question.CorrectAnswerIndex = model.CorrectAnswerIndex;
        question.Hint = model.Hint;
        await database.SaveChangesAsync(cancellationToken);

        TempData["StatusMessage"] = $"Đã cập nhật câu {question.Number}.";
        return RedirectToAction(nameof(Edit), new { id, questionId });
    }

    [HttpPost("{id:guid}/passages/{passageId:guid}")]
    [ValidateAntiForgeryToken]
    [DisableValidation]
    public async Task<IActionResult> EditPassage(
        Guid id,
        Guid passageId,
        EditExamPassageViewModel model,
        CancellationToken cancellationToken)
    {
        if (model.ExamId != id || model.PassageId != passageId)
        {
            return BadRequest();
        }

        model.Content = model.Content?.Trim() ?? string.Empty;
        TryValidateModel(model);
        if (!ModelState.IsValid)
        {
            TempData["StatusMessage"] = "Không lưu được đoạn đọc. Nội dung không được để trống và tối đa 20.000 ký tự.";
            return RedirectToAction(
                nameof(Edit),
                new { id, questionId = model.SelectedQuestionId });
        }

        var passage = await database.Passages
            .SingleOrDefaultAsync(
                item => item.Id == passageId && item.ExamId == id,
                cancellationToken);
        if (passage is null)
        {
            return NotFound();
        }

        passage.Content = model.Content;
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đã cập nhật đoạn đọc.";
        return RedirectToAction(
            nameof(Edit),
            new { id, questionId = model.SelectedQuestionId });
    }

    [HttpPost("{id:guid}/publish")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Publish(Guid id, CancellationToken cancellationToken)
    {
        var exam = await database.Exams
            .Include(item => item.Questions)
                .ThenInclude(question => question.Passage)
            .Include(item => item.Sessions)
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null)
        {
            return NotFound();
        }

        var publicationIssues = new EditExamViewModel
        {
            Questions = BuildReviewItems(exam.Questions),
        }.PublicationIssues;
        if (publicationIssues.Count > 0)
        {
            TempData["StatusMessage"] = $"Không thể xuất bản: {string.Join(" ", publicationIssues)}";
            return RedirectToAction(nameof(Edit), new { id });
        }

        exam.IsPublished = true;
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đề thi đã được xuất bản cho sinh viên.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost("{id:guid}/unpublish")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Unpublish(Guid id, CancellationToken cancellationToken)
    {
        var exam = await database.Exams
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null)
        {
            return NotFound();
        }

        exam.IsPublished = false;
        exam.IsSessionActive = false;
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = "Đề thi đã được chuyển về bản nháp.";
        return RedirectToAction(nameof(Edit), new { id });
    }

    [HttpPost("{id:guid}/session")]
    [ValidateAntiForgeryToken]
    [DisableValidation]
    public async Task<IActionResult> SetSessionActive(
        Guid id,
        bool isActive,
        CancellationToken cancellationToken)
    {
        var exam = await database.Exams
            .Include(item => item.Questions)
                .ThenInclude(question => question.Passage)
            .Include(item => item.Sessions)
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (exam is null)
        {
            return NotFound();
        }

        if (isActive)
        {
            if (!exam.IsPublished)
            {
                TempData["StatusMessage"] = "Chỉ có thể kích hoạt ca thi của đề đã xuất bản.";
                return RedirectToAction(nameof(Index));
            }

            if (!exam.Sessions.Any(session =>
                    session.SessionDate is not null
                    && session.SessionStart is not null
                    && session.SessionEnd > session.SessionStart))
            {
                TempData["StatusMessage"] =
                    "Hãy tạo ít nhất một ca thi có ngày, giờ bắt đầu và giờ kết thúc hợp lệ trước khi bật.";
                return RedirectToAction(nameof(Edit), new { id });
            }

            var publicationIssues = new EditExamViewModel
            {
                Questions = BuildReviewItems(exam.Questions),
            }.PublicationIssues;
            if (publicationIssues.Count > 0)
            {
                TempData["StatusMessage"] =
                    $"Không thể kích hoạt ca thi: {string.Join(" ", publicationIssues)}";
                return RedirectToAction(nameof(Edit), new { id });
            }
        }

        exam.IsSessionActive = isActive;
        await database.SaveChangesAsync(cancellationToken);
        TempData["StatusMessage"] = isActive
            ? "Đã bật hiển thị. Đề thi và các ca đã cấu hình sẽ xuất hiện trong danh sách của sinh viên."
            : "Đã tắt hiển thị. Đề thi sẽ không còn xuất hiện trong danh sách của sinh viên.";
        return RedirectToAction(nameof(Index));
    }

    private static IReadOnlyList<ExamQuestionReviewItem> BuildReviewItems(
        IEnumerable<Question> questions)
    {
        return questions
            .OrderBy(question => question.Number)
            .Select(question => new ExamQuestionReviewItem(
                question.Id,
                question.Number,
                question.Part,
                question.Prompt,
                question.ChoiceA,
                question.ChoiceB,
                question.ChoiceC,
                question.ChoiceD,
                question.CorrectAnswerIndex,
                question.Hint,
                question.PassageId,
                question.Passage?.Part,
                question.Passage?.Content))
            .ToList();
    }
}
