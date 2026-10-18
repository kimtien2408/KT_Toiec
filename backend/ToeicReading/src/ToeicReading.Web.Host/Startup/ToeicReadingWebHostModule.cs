using Abp.Modules;
using Abp.Reflection.Extensions;
using ToeicReading.Configuration;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace ToeicReading.Web.Host.Startup
{
    [DependsOn(
       typeof(ToeicReadingWebCoreModule))]
    public class ToeicReadingWebHostModule : AbpModule
    {
        private readonly IWebHostEnvironment _env;
        private readonly IConfigurationRoot _appConfiguration;

        public ToeicReadingWebHostModule(IWebHostEnvironment env)
        {
            _env = env;
            _appConfiguration = env.GetAppConfiguration();
        }

        public override void Initialize()
        {
            IocManager.RegisterAssemblyByConvention(typeof(ToeicReadingWebHostModule).GetAssembly());
        }
    }
}
