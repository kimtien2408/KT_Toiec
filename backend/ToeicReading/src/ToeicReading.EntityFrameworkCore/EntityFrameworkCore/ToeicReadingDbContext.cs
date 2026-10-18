using Abp.Zero.EntityFrameworkCore;
using ToeicReading.Authorization.Roles;
using ToeicReading.Authorization.Users;
using ToeicReading.MultiTenancy;
using Microsoft.EntityFrameworkCore;

namespace ToeicReading.EntityFrameworkCore;

public class ToeicReadingDbContext : AbpZeroDbContext<Tenant, Role, User, ToeicReadingDbContext>
{
    /* Define a DbSet for each entity of the application */

    public ToeicReadingDbContext(DbContextOptions<ToeicReadingDbContext> options)
        : base(options)
    {
    }
}
