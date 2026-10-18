namespace backend.Models;

public static class StaffRoles
{
    public const string Admin = "Admin";
    public const string Instructor = "Instructor";
}

public sealed class StaffAccount
{
    public Guid Id { get; set; }
    public required string UserName { get; set; }
    public required string NormalizedUserName { get; set; }
    public required string DisplayName { get; set; }
    public required string Role { get; set; }
    public required string PasswordHash { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
