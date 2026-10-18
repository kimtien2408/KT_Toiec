using backend.Data;
using backend.Models;
using backend.Models.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[Route("instructor/classes")]
[Authorize(Roles = StaffRoles.Admin + "," + StaffRoles.Instructor)]
public sealed class StudentClassesController(ToeicDbContext database) : Controller
{
    [HttpGet("")]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "students";
        var classes = await database.StudentClasses
            .AsNoTracking()
            .OrderBy(item => item.Name)
            .Select(item => new StudentClassListItem(
                item.Id,
                item.Name,
                item.Code,
                item.AcademicYear,
                item.Students.Count,
                item.CreatedAt))
            .ToListAsync(cancellationToken);

        return View(classes);
    }

    [HttpGet("create")]
    public IActionResult Create()
    {
        ViewData["ActiveNav"] = "students";
        return View(new CreateStudentClassViewModel());
    }

    [HttpPost("create")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(
        CreateStudentClassViewModel model,
        CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "students";
        model.Name = model.Name.Trim();
        model.Code = model.Code.Trim().ToUpperInvariant();
        model.AcademicYear = string.IsNullOrWhiteSpace(model.AcademicYear)
            ? null
            : model.AcademicYear.Trim();

        if (await database.StudentClasses.AnyAsync(
                item => item.Code == model.Code,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Code), "Mã lớp này đã tồn tại.");
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var studentClass = new StudentClass
        {
            Id = Guid.NewGuid(),
            Name = model.Name,
            Code = model.Code,
            AcademicYear = model.AcademicYear,
        };
        database.StudentClasses.Add(studentClass);
        await database.SaveChangesAsync(cancellationToken);

        TempData["StatusMessage"] = $"Đã tạo lớp {studentClass.Name}.";
        return RedirectToAction(nameof(Details), new { id = studentClass.Id });
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Details(
        Guid id,
        CancellationToken cancellationToken)
    {
        ViewData["ActiveNav"] = "students";
        var studentClass = await database.StudentClasses
            .AsNoTracking()
            .Where(item => item.Id == id)
            .Select(item => new StudentClassDetailsViewModel(
                new StudentClassListItem(
                    item.Id,
                    item.Name,
                    item.Code,
                    item.AcademicYear,
                    item.Students.Count,
                    item.CreatedAt),
                item.Students
                    .OrderBy(student => student.StudentCode)
                    .Select(student => new StudentListItem(
                        student.Id,
                        student.StudentCode,
                        student.FullName,
                        student.Email,
                        student.CreatedAt))
                    .ToList()))
            .SingleOrDefaultAsync(cancellationToken);

        return studentClass is null ? NotFound() : View(studentClass);
    }

    [HttpPost("{id:guid}/students")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddStudent(
        Guid id,
        AddStudentViewModel model,
        CancellationToken cancellationToken)
    {
        if (id != model.ClassId)
        {
            return BadRequest();
        }

        model.StudentCode = model.StudentCode.Trim();
        model.FullName = model.FullName.Trim();
        model.Email = string.IsNullOrWhiteSpace(model.Email)
            ? null
            : model.Email.Trim();

        var studentClass = await database.StudentClasses
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (studentClass is null)
        {
            return NotFound();
        }

        if (await database.Students.AnyAsync(
                student => student.ClassId == id
                    && student.StudentCode == model.StudentCode,
                cancellationToken))
        {
            TempData["ErrorMessage"] =
                $"Mã sinh viên {model.StudentCode} đã có trong lớp này.";
            return RedirectToAction(nameof(Details), new { id });
        }

        if (!ModelState.IsValid)
        {
            TempData["ErrorMessage"] = string.Join(
                " ",
                ModelState.Values
                    .SelectMany(value => value.Errors)
                    .Select(error => error.ErrorMessage));
            return RedirectToAction(nameof(Details), new { id });
        }

        database.Students.Add(new Student
        {
            Id = Guid.NewGuid(),
            ClassId = id,
            StudentCode = model.StudentCode,
            FullName = model.FullName,
            Email = model.Email,
        });
        await database.SaveChangesAsync(cancellationToken);

        TempData["StatusMessage"] = $"Đã thêm sinh viên {model.FullName} vào lớp.";
        return RedirectToAction(nameof(Details), new { id });
    }
}
