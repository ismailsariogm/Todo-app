# Flutter web dev sunucusu (localhost:8080) yanit verince tarayiciyi acar.
# start_app.ps1 tarafindan ayri bir surecte calistirilir.

$ErrorActionPreference = 'SilentlyContinue'
$port = 8080
if ($env:TODO_WEB_PORT -and $env:TODO_WEB_PORT -match '^\d+$') {
  $port = [int]$env:TODO_WEB_PORT
}
$url = "http://localhost:$port"

for ($i = 0; $i -lt 180; $i++) {
  try {
    $null = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    break
  } catch {
    Start-Sleep -Milliseconds 500
  }
}

$opened = $false
try {
  Start-Process $url -ErrorAction Stop
  $opened = $true
} catch { }

if (-not $opened) {
  & cmd.exe /c "start `"`" `"$url`""
  if ($LASTEXITCODE -eq 0) { $opened = $true }
}

if (-not $opened) {
  $candidates = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    "${env:LocalAppData}\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  )
  foreach ($exe in $candidates) {
    if (Test-Path -LiteralPath $exe) {
      Start-Process -FilePath $exe -ArgumentList $url, '--new-window'
      break
    }
  }
}
