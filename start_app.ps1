# Todo Uygulamasi Baslatici
# Kullanim: .\start_app.ps1

$projectRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$dbFile = Join-Path $projectRoot "app_db.json"

Write-Host ""
Write-Host "Todo Uygulamasi - Baslatiliyor" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $dbFile)) {
  Write-Host "  Veritabani dosyasi olusturuluyor..." -ForegroundColor Yellow
  '{"users":[],"tasks":[],"projects":[],"members":[],"user_registry":[],"friends":{},"conversations":{},"messages":{}}' | Set-Content $dbFile -Encoding UTF8
}
Write-Host "  Veritabani: $dbFile" -ForegroundColor Green

foreach ($port in 8080, 3001) {
  $line = netstat -ano 2>$null | Select-String ":$port " | Select-String "LISTENING" | Select-Object -First 1
  if ($line) {
    $pid_ = ($line.Line -split '\s+')[-1]
    if ($pid_ -match '^\d+$') {
      Stop-Process -Id ([int]$pid_) -Force -ErrorAction SilentlyContinue
      Write-Host "  Port $port temizlendi." -ForegroundColor Yellow
    }
  }
}
Start-Sleep -Milliseconds 800

Write-Host ""
Write-Host "  Veritabani sunucusu baslatiliyor (port 3001)..." -ForegroundColor Green
$serverProc = Start-Process -FilePath "dart" -ArgumentList "run", "tool/db_server.dart" -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden

$serverReady = $false
for ($i = 0; $i -lt 15; $i++) {
  Start-Sleep -Milliseconds 600
  try {
    $resp = Invoke-RestMethod -Uri "http://localhost:3001/health" -Method Get -TimeoutSec 1 -ErrorAction Stop
    if ($resp.status -eq "ok") {
      $serverReady = $true
      Write-Host "  DB Sunucusu hazir!" -ForegroundColor Green
      break
    }
  } catch { }
}

if (-not $serverReady) {
  Write-Host "  DB Sunucusu baslatilamadi - SharedPreferences yedek kullanilacak." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Flutter baslatiliyor -> http://localhost:8080" -ForegroundColor Cyan
Write-Host "  Durdurmak icin: Ctrl+C" -ForegroundColor DarkGray
Write-Host ""

try {
  Set-Location $projectRoot
  flutter run -d chrome --web-port 8080
} finally {
  if ($serverProc -and -not $serverProc.HasExited) {
    $serverProc.Kill()
    Write-Host "  DB Sunucusu kapatildi." -ForegroundColor DarkGray
  }
  Write-Host "  Veriler kaydedildi: $dbFile" -ForegroundColor Green
}
