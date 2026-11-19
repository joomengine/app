[CmdletBinding()]
param([Parameter(Mandatory)][string]$Executable)
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
    Write-Host "JoomEngine rendered: $($app.MainWindowTitle)"
} finally {
    if (-not $app.HasExited) {
        $null = $app.CloseMainWindow()
        if (-not $app.WaitForExit(15000)) { $app.Kill() }
    }
}
