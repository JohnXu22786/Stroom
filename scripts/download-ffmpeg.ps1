param(
    [string]$OutputDir = "assets/ffmpeg"
)

Write-Host "Downloading FFmpeg for Windows..." -ForegroundColor Green

$ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$zipPath = "$env:TEMP\ffmpeg-release-essentials.zip"
$extractDir = "$env:TEMP\ffmpeg-extract"

# 下载
Write-Host "Downloading from $ffmpegUrl ..."
Invoke-WebRequest -Uri $ffmpegUrl -OutFile $zipPath

# 解压
Write-Host "Extracting..."
if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

# 查找 ffmpeg.exe
$ffmpegExe = Get-ChildItem -Path $extractDir -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
if ($ffmpegExe) {
    $outputPath = Join-Path $OutputDir "ffmpeg_windows.exe"
    Copy-Item -Path $ffmpegExe.FullName -Destination $outputPath -Force
    Write-Host "FFmpeg for Windows saved to: $outputPath" -ForegroundColor Green
} else {
    Write-Host "ERROR: ffmpeg.exe not found in extracted archive" -ForegroundColor Red
    exit 1
}

# 清理
Remove-Item -Recurse -Force $extractDir
Remove-Item -Force $zipPath

Write-Host "Done!" -ForegroundColor Green
