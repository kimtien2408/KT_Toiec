using Abp.AspNetCore.Configuration;
using Abp.AspNetCore.Mvc.Auditing;
using Abp.AspNetCore.Mvc.Authorization;
using Abp.AspNetCore.Mvc.ExceptionHandling;
using Abp.AspNetCore.Mvc.Results;
using Abp.AspNetCore.Mvc.Uow;
using Abp.AspNetCore.Mvc.Validation;
using Abp.AspNetCore;
using Abp.Dependency;
using backend.Controllers;
using backend.Data;
using backend.Models;
using backend.Modules;
using backend.Services;
using Castle.MicroKernel.Registration;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("ToeicDatabase")
    ?? throw new InvalidOperationException(
        "Connection string 'ToeicDatabase' is not configured.");

var applicationPartManager = new ApplicationPartManager();
var httpContextAccessor = new HttpContextAccessor();
foreach (var applicationPart in ApplicationPartFactory
             .GetApplicationPartFactory(typeof(Program).Assembly)
             .GetApplicationParts(typeof(Program).Assembly))
{
    applicationPartManager.ApplicationParts.Add(applicationPart);
}
applicationPartManager.FeatureProviders.Add(new ControllerFeatureProvider());
builder.Services.AddSingleton(applicationPartManager);
builder.Services.AddSingleton<IHttpContextAccessor>(httpContextAccessor);
builder.Services.AddControllersWithViews();
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/account/login";
        options.LogoutPath = "/account/logout";
        options.AccessDeniedPath = "/account/login";
        options.Cookie.Name = "Readwise.Staff";
        options.Cookie.HttpOnly = true;
        options.Cookie.IsEssential = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = builder.Environment.IsDevelopment()
            ? CookieSecurePolicy.SameAsRequest
            : CookieSecurePolicy.Always;
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
    });
builder.Services.AddAuthorization();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("staff-login", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));
});
builder.Services.AddSingleton<IPasswordHasher<StaffAccount>, PasswordHasher<StaffAccount>>();
builder.Services.AddCors(options => options.AddPolicy(
    "FlutterDevelopment",
    policy => policy
        .SetIsOriginAllowed(origin => Uri.TryCreate(origin, UriKind.Absolute, out var uri)
            && (uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
                || uri.Host.Equals("127.0.0.1", StringComparison.Ordinal)))
        .AllowAnyHeader()
        .AllowAnyMethod()));
builder.Services.AddTransient<ExamsController>();
builder.Services.AddTransient<InstructorExamsController>();
builder.Services.AddTransient<StudentClassesController>();
builder.Services.AddTransient<AccountController>();
builder.Services.AddTransient<StaffAccountSeeder>();
builder.Services.AddSingleton<ExamDocxParser>();
builder.Services.AddSingleton<IIocManager>(IocManager.Instance);
builder.Services.AddSingleton<IIocResolver>(IocManager.Instance);
builder.Services.AddSingleton<IAbpAspNetCoreConfiguration>(
    _ => IocManager.Instance.Resolve<IAbpAspNetCoreConfiguration>());
var abpMvcFilters = new[]
{
    typeof(AbpAuthorizationFilter),
    typeof(AbpAuditActionFilter),
    typeof(AbpValidationActionFilter),
    typeof(AbpUowActionFilter),
    typeof(AbpExceptionFilter),
    typeof(AbpResultFilter),
    typeof(AbpUowPageFilter),
    typeof(AbpAuditPageFilter),
    typeof(AbpResultPageFilter),
    typeof(AbpExceptionPageFilter),
};
foreach (var filterType in abpMvcFilters)
{
    builder.Services.AddTransient(filterType, _ => IocManager.Instance.Resolve(filterType));
}
builder.Services.AddOpenApi();
builder.Services.AddDbContext<ToeicDbContext>(options =>
    options.UseSqlServer(connectionString));
builder.Services.AddAbpWithoutCreatingServiceProvider<ToeicBackendModule>(options =>
{
    options.IocManager.IocContainer.Register(
        Component.For<IConfiguration>()
            .Instance(builder.Configuration),
        Component.For<ApplicationPartManager>()
            .Instance(applicationPartManager),
        Component.For<IHttpContextAccessor>()
            .Instance(httpContextAccessor),
        Component.For<IOptions<AntiforgeryOptions>>()
            .Instance(Options.Create(new AntiforgeryOptions())));
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseCors("FlutterDevelopment");
}
app.UseAbp(options => options.UseAbpRequestLocalization = false);
app.UseHttpsRedirection();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();

    await using var scope = app.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<ToeicDbContext>();
    await database.Database.EnsureCreatedAsync();
    await database.Database.ExecuteSqlRawAsync(
        """
        IF OBJECT_ID(N'dbo.ToeicExams', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicExams (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicExams PRIMARY KEY,
                Title nvarchar(200) NOT NULL,
                DurationMinutes int NOT NULL,
                IsPublished bit NOT NULL,
                IsSessionActive bit NOT NULL CONSTRAINT DF_ToeicExams_IsSessionActive DEFAULT (0),
                SessionShift nvarchar(16) NOT NULL CONSTRAINT DF_ToeicExams_SessionShift DEFAULT (N'Morning'),
                SessionDate date NULL,
                SessionStart time NULL,
                SessionEnd time NULL,
                SessionCode nvarchar(30) NULL,
                CreatedAt datetime2 NOT NULL
            );
        END;

        IF COL_LENGTH(N'dbo.ToeicExams', N'IsSessionActive') IS NULL
        BEGIN
            ALTER TABLE dbo.ToeicExams
                ADD IsSessionActive bit NOT NULL
                    CONSTRAINT DF_ToeicExams_IsSessionActive DEFAULT (0) WITH VALUES;
        END;

        IF COL_LENGTH(N'dbo.ToeicExams', N'SessionShift') IS NULL
        BEGIN
            ALTER TABLE dbo.ToeicExams
                ADD SessionShift nvarchar(16) NOT NULL
                    CONSTRAINT DF_ToeicExams_SessionShift DEFAULT (N'Morning') WITH VALUES;
        END;

        IF COL_LENGTH(N'dbo.ToeicExams', N'SessionDate') IS NULL
            ALTER TABLE dbo.ToeicExams ADD SessionDate date NULL;

        IF COL_LENGTH(N'dbo.ToeicExams', N'SessionStart') IS NULL
            ALTER TABLE dbo.ToeicExams ADD SessionStart time NULL;

        IF COL_LENGTH(N'dbo.ToeicExams', N'SessionEnd') IS NULL
            ALTER TABLE dbo.ToeicExams ADD SessionEnd time NULL;

        IF COL_LENGTH(N'dbo.ToeicExams', N'SessionCode') IS NULL
            ALTER TABLE dbo.ToeicExams ADD SessionCode nvarchar(30) NULL;

        IF OBJECT_ID(N'dbo.ToeicExamSessions', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicExamSessions (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicExamSessions PRIMARY KEY,
                ExamId uniqueidentifier NOT NULL,
                Shift nvarchar(16) NOT NULL,
                SessionDate date NULL,
                SessionStart time NULL,
                SessionEnd time NULL,
                SessionCode nvarchar(30) NULL,
                CONSTRAINT FK_ToeicExamSessions_ToeicExams_ExamId
                    FOREIGN KEY (ExamId) REFERENCES dbo.ToeicExams(Id) ON DELETE CASCADE
            );
        END;

        UPDATE dbo.ToeicExams
        SET SessionDate = '2026-10-20', SessionStart = '08:00', SessionEnd = '09:15'
        WHERE Id = 'c5762312-3f6b-46d0-8f96-4ab270837001'
            AND SessionDate IS NULL;

        UPDATE dbo.ToeicExamSessions
        SET SessionDate = '2026-10-20', SessionStart = '08:00', SessionEnd = '09:15'
        WHERE ExamId = 'c5762312-3f6b-46d0-8f96-4ab270837001'
            AND SessionDate IS NULL;

        INSERT INTO dbo.ToeicExamSessions
            (Id, ExamId, Shift, SessionDate, SessionStart, SessionEnd, SessionCode)
        SELECT NEWID(), exam.Id, exam.SessionShift, exam.SessionDate,
            exam.SessionStart, exam.SessionEnd, exam.SessionCode
        FROM dbo.ToeicExams AS exam
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.ToeicExamSessions AS session
            WHERE session.ExamId = exam.Id
        );

        IF OBJECT_ID(N'dbo.ToeicPassages', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicPassages (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicPassages PRIMARY KEY,
                ExamId uniqueidentifier NOT NULL,
                Part int NOT NULL,
                Content nvarchar(max) NOT NULL,
                CONSTRAINT FK_ToeicPassages_ToeicExams_ExamId
                    FOREIGN KEY (ExamId) REFERENCES dbo.ToeicExams(Id) ON DELETE CASCADE
            );
        END;

        IF OBJECT_ID(N'dbo.ToeicQuestions', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicQuestions (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicQuestions PRIMARY KEY,
                ExamId uniqueidentifier NOT NULL,
                PassageId uniqueidentifier NULL,
                Number int NOT NULL,
                Part int NOT NULL,
                Prompt nvarchar(max) NOT NULL,
                ChoiceA nvarchar(max) NOT NULL,
                ChoiceB nvarchar(max) NOT NULL,
                ChoiceC nvarchar(max) NOT NULL,
                ChoiceD nvarchar(max) NOT NULL,
                CorrectAnswerIndex int NOT NULL,
                Hint nvarchar(max) NULL,
                CONSTRAINT FK_ToeicQuestions_ToeicExams_ExamId
                    FOREIGN KEY (ExamId) REFERENCES dbo.ToeicExams(Id) ON DELETE CASCADE,
                CONSTRAINT FK_ToeicQuestions_ToeicPassages_PassageId
                    FOREIGN KEY (PassageId) REFERENCES dbo.ToeicPassages(Id)
            );
            CREATE UNIQUE INDEX IX_ToeicQuestions_ExamId_Number
                ON dbo.ToeicQuestions(ExamId, Number);
        END;

        IF OBJECT_ID(N'dbo.ToeicExamAttempts', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicExamAttempts (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicExamAttempts PRIMARY KEY,
                ExamId uniqueidentifier NOT NULL,
                ExamSessionId uniqueidentifier NULL,
                SubmittedAt datetime2 NOT NULL,
                CONSTRAINT FK_ToeicExamAttempts_ToeicExams_ExamId
                    FOREIGN KEY (ExamId) REFERENCES dbo.ToeicExams(Id) ON DELETE CASCADE,
                CONSTRAINT FK_ToeicExamAttempts_ToeicExamSessions_ExamSessionId
                    FOREIGN KEY (ExamSessionId) REFERENCES dbo.ToeicExamSessions(Id)
            );
        END;

        IF COL_LENGTH(N'dbo.ToeicExamAttempts', N'ExamSessionId') IS NULL
        BEGIN
            ALTER TABLE dbo.ToeicExamAttempts ADD ExamSessionId uniqueidentifier NULL;
            ALTER TABLE dbo.ToeicExamAttempts
                ADD CONSTRAINT FK_ToeicExamAttempts_ToeicExamSessions_ExamSessionId
                    FOREIGN KEY (ExamSessionId) REFERENCES dbo.ToeicExamSessions(Id);
        END;

        IF OBJECT_ID(N'dbo.ToeicAttemptAnswers', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicAttemptAnswers (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicAttemptAnswers PRIMARY KEY,
                AttemptId uniqueidentifier NOT NULL,
                QuestionId uniqueidentifier NOT NULL,
                SelectedAnswerIndex int NULL,
                IsCorrect bit NOT NULL,
                CONSTRAINT FK_ToeicAttemptAnswers_ToeicExamAttempts_AttemptId
                    FOREIGN KEY (AttemptId) REFERENCES dbo.ToeicExamAttempts(Id) ON DELETE CASCADE,
                CONSTRAINT FK_ToeicAttemptAnswers_ToeicQuestions_QuestionId
                    FOREIGN KEY (QuestionId) REFERENCES dbo.ToeicQuestions(Id)
            );
        END;

        IF OBJECT_ID(N'dbo.StudentClasses', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.StudentClasses (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_StudentClasses PRIMARY KEY,
                Name nvarchar(120) NOT NULL,
                Code nvarchar(30) NOT NULL,
                AcademicYear nvarchar(30) NULL,
                CreatedAt datetime2 NOT NULL
            );
            CREATE UNIQUE INDEX IX_StudentClasses_Code ON dbo.StudentClasses(Code);
        END;

        IF OBJECT_ID(N'dbo.Students', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.Students (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_Students PRIMARY KEY,
                ClassId uniqueidentifier NOT NULL,
                StudentCode nvarchar(30) NOT NULL,
                FullName nvarchar(120) NOT NULL,
                Email nvarchar(254) NULL,
                CreatedAt datetime2 NOT NULL,
                CONSTRAINT FK_Students_StudentClasses_ClassId
                    FOREIGN KEY (ClassId) REFERENCES dbo.StudentClasses(Id) ON DELETE CASCADE
            );
            CREATE UNIQUE INDEX IX_Students_ClassId_StudentCode
                ON dbo.Students(ClassId, StudentCode);
        END;
        """);
}

await using (var scope = app.Services.CreateAsyncScope())
{
    var database = scope.ServiceProvider.GetRequiredService<ToeicDbContext>();
    await database.Database.ExecuteSqlRawAsync(
        """
        IF OBJECT_ID(N'dbo.ToeicStaffAccounts', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ToeicStaffAccounts (
                Id uniqueidentifier NOT NULL CONSTRAINT PK_ToeicStaffAccounts PRIMARY KEY,
                UserName nvarchar(64) NOT NULL,
                NormalizedUserName nvarchar(64) NOT NULL,
                DisplayName nvarchar(120) NOT NULL,
                Role nvarchar(32) NOT NULL,
                PasswordHash nvarchar(512) NOT NULL,
                CreatedAt datetime2 NOT NULL
            );
        END;

        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.ToeicStaffAccounts')
                AND name = N'IX_ToeicStaffAccounts_NormalizedUserName'
        )
        BEGIN
            CREATE UNIQUE INDEX IX_ToeicStaffAccounts_NormalizedUserName
                ON dbo.ToeicStaffAccounts(NormalizedUserName);
        END;
        """);
    await scope.ServiceProvider
        .GetRequiredService<StaffAccountSeeder>()
        .SeedAsync();
}

app.MapControllers();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=InstructorExams}/{action=Home}/{id?}");

app.Run();
