using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

public sealed class StaffAccountSeeder(
    ToeicDbContext database,
    IConfiguration configuration,
    IPasswordHasher<StaffAccount> passwordHasher)
{
    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var configuredAccounts = configuration
            .GetSection("InitialStaffAccounts")
            .Get<List<InitialStaffAccount>>() ?? [];

        foreach (var role in new[] { StaffRoles.Admin, StaffRoles.Instructor })
        {
            var roleExists = await database.StaffAccounts
                .AnyAsync(account => account.Role == role, cancellationToken);
            if (roleExists)
            {
                continue;
            }

            var initialAccount = configuredAccounts.SingleOrDefault(
                account => string.Equals(account.Role, role, StringComparison.Ordinal));
            if (initialAccount is null
                || string.IsNullOrWhiteSpace(initialAccount.UserName)
                || string.IsNullOrWhiteSpace(initialAccount.DisplayName)
                || string.IsNullOrWhiteSpace(initialAccount.Password)
                || initialAccount.Password.Length < 12)
            {
                throw new InvalidOperationException(
                    $"Configure a username, display name, and password of at least 12 characters for the {role} account in InitialStaffAccounts.");
            }

            var userName = initialAccount.UserName.Trim();
            var account = new StaffAccount
            {
                Id = Guid.NewGuid(),
                UserName = userName,
                NormalizedUserName = userName.ToUpperInvariant(),
                DisplayName = initialAccount.DisplayName.Trim(),
                Role = role,
                PasswordHash = string.Empty,
            };
            account.PasswordHash = passwordHasher.HashPassword(
                account,
                initialAccount.Password);
            database.StaffAccounts.Add(account);
        }

        await database.SaveChangesAsync(cancellationToken);
    }

    private sealed class InitialStaffAccount
    {
        public string Role { get; init; } = string.Empty;
        public string UserName { get; init; } = string.Empty;
        public string DisplayName { get; init; } = string.Empty;
        public string Password { get; init; } = string.Empty;
    }
}
