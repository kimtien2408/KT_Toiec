using Abp.AspNetCore;
using Abp.Dependency;
using Abp.EntityFrameworkCore;
using Abp.EntityFrameworkCore.Configuration;
using Abp.Modules;
using backend.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace backend.Modules;

[DependsOn(
    typeof(AbpAspNetCoreModule),
    typeof(AbpEntityFrameworkCoreModule))]
public sealed class ToeicBackendModule : AbpModule
{
    public override void PreInitialize()
    {
        var configuration = IocManager.Resolve<IConfiguration>();
        var connectionString = configuration.GetConnectionString("ToeicDatabase")
            ?? throw new InvalidOperationException(
                "Connection string 'ToeicDatabase' is not configured.");

        Configuration.Modules.AbpEfCore().AddDbContext<ToeicDbContext>(options =>
        {
            options.DbContextOptions.UseSqlServer(connectionString);
        });
    }

    public override void Initialize()
    {
        IocManager.RegisterAssemblyByConvention(typeof(ToeicBackendModule).Assembly);
    }
}
