$setup = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
$args = @(
  "modify",
  "--installPath", "`"C:\Program Files\Microsoft Visual Studio\18\Insiders`"",
  "--add", "Microsoft.VisualStudio.Workload.NativeDesktop",
  "--includeRecommended",
  "--installWhileDownloading",
  "--quiet"
)
Start-Process -FilePath $setup -ArgumentList $args -Verb RunAs -Wait
