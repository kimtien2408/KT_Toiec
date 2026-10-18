using System.Security.Claims;
using backend.Data;
using backend.Models;
using backend.Models.ViewModels;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[Route("account")]
public sealed class AccountController(
    ToeicDbContext database,
    IPasswordHasher<StaffAccount> passwordHasher) : Controller
{
    [AllowAnonymous]
    [HttpGet("login")]
    public IActionResult Login([FromQuery] string? returnUrl)
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToAction("Home", "InstructorExams");
        }

        return View(new StaffLoginViewModel { ReturnUrl = returnUrl });
    }

    [AllowAnonymous]
    [HttpPost("login")]
    [EnableRateLimiting("staff-login")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(
        StaffLoginViewModel model,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            model.Password = string.Empty;
            return View(model);
        }

        var normalizedUserName = model.UserName.Trim().ToUpperInvariant();
        var account = await database.StaffAccounts
            .SingleOrDefaultAsync(
                item => item.NormalizedUserName == normalizedUserName,
                cancellationToken);
        if (account is null
            || account.Role is not (StaffRoles.Admin or StaffRoles.Instructor)
            || passwordHasher.VerifyHashedPassword(
                account,
                account.PasswordHash,
                model.Password) == PasswordVerificationResult.Failed)
        {
            ModelState.AddModelError(string.Empty, "Tên đăng nhập hoặc mật khẩu không chính xác.");
            model.Password = string.Empty;
            return View(model);
        }

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, account.Id.ToString()),
            new Claim(ClaimTypes.Name, account.UserName),
            new Claim(ClaimTypes.GivenName, account.DisplayName),
            new Claim(ClaimTypes.Role, account.Role),
        };
        var identity = new ClaimsIdentity(
            claims,
            CookieAuthenticationDefaults.AuthenticationScheme);
        var authenticationProperties = new AuthenticationProperties
        {
            IsPersistent = model.RememberMe,
            AllowRefresh = true,
        };
        if (model.RememberMe)
        {
            authenticationProperties.ExpiresUtc = DateTimeOffset.UtcNow.AddDays(14);
        }
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            authenticationProperties);

        if (!string.IsNullOrWhiteSpace(model.ReturnUrl)
            && Url.IsLocalUrl(model.ReturnUrl))
        {
            return LocalRedirect(model.ReturnUrl);
        }

        return RedirectToAction("Home", "InstructorExams");
    }

    [Authorize]
    [HttpPost("logout")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(
            CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }
}
