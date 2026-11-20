[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [string]$PackageFamilyName
)
$ErrorActionPreference = 'Stop'

$app = Start-Process -FilePath $Executable -PassThru
try {
    $deadline = [DateTime]::UtcNow.AddMinutes(2)
    do {
        Start-Sleep -Milliseconds 400
        $app.Refresh()
        if ($app.HasExited) { throw "JoomEngine exited during startup ($($app.ExitCode))." }
    } until ($app.MainWindowTitle -like '*JoomEngine Rocket*' -or [DateTime]::UtcNow -ge $deadline)
    if ($app.MainWindowTitle -notlike '*JoomEngine Rocket*') {
        throw "The installed WebView2 host did not render the live Playground. Window title: $($app.MainWindowTitle)"
    }
    $roots = @((Join-Path $env:LOCALAPPDATA 'JoomEngine/WebView2'))
    if ($PackageFamilyName) {
        # Windows may virtualize LocalAppData writes for a packaged desktop app.
        $roots += Join-Path $env:LOCALAPPDATA "Packages/$PackageFamilyName/LocalCache/Local/JoomEngine/WebView2"
    }
    $profileFile = $roots | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Recurse -File -ErrorAction SilentlyContinue
    } | Where-Object { $_.Length -gt 0 } | Select-Object -First 1
    if (-not $profileFile) { throw 'The installed app did not write a WebView2 profile under local user application data.' }
    Write-Host "JoomEngine rendered: $($app.MainWindowTitle) and wrote its local user profile."
} finally {
    if (-not $app.HasExited) {
        $null = $app.CloseMainWindow()
        if (-not $app.WaitForExit(15000)) { $app.Kill() }
    }
}
