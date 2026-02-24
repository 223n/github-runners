<#
.SYNOPSIS
    GitHub Actions セルフホステッドランナーの管理スクリプト

.DESCRIPTION
    Docker Composeベースのランナーを起動・停止・状態確認・ログ表示する。
    Docker Desktopが未起動の場合は自動で起動して待機する。

.EXAMPLE
    .\runner.ps1 start
    .\runner.ps1 stop
    .\runner.ps1 status
    .\runner.ps1 logs runner-sleep-diary
    .\runner.ps1 restart
    .\runner.ps1 clean
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "clean", "help")]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Docker Desktopの起動待機タイムアウト（秒）
$DOCKER_TIMEOUT = 120

function Test-DockerReady {
    try {
        docker info 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Start-DockerDesktop {
    if (Test-DockerReady) {
        Write-Host "Docker Desktopは起動済みです。" -ForegroundColor Green
        return
    }

    Write-Host "Docker Desktopを起動しています..." -ForegroundColor Yellow

    # Docker Desktopの実行ファイルパスを検索
    $dockerPath = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $dockerPath) {
        Write-Host "エラー: Docker Desktopが見つかりません。" -ForegroundColor Red
        exit 1
    }

    Start-Process $dockerPath

    Write-Host "Docker Desktopの準備完了を待機しています（タイムアウト: ${DOCKER_TIMEOUT}秒）..." -ForegroundColor Yellow
    $elapsed = 0
    while (-not (Test-DockerReady)) {
        if ($elapsed -ge $DOCKER_TIMEOUT) {
            Write-Host "エラー: Docker Desktopの起動がタイムアウトしました。" -ForegroundColor Red
            exit 1
        }
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "  待機中... (${elapsed}秒)" -ForegroundColor Gray
    }

    Write-Host "Docker Desktopの準備が完了しました。" -ForegroundColor Green
}

function Invoke-ComposeStart {
    Start-DockerDesktop
    Write-Host "ランナーを起動しています..." -ForegroundColor Yellow
    docker compose up -d
    if ($LASTEXITCODE -eq 0) {
        Write-Host "全ランナーの起動が完了しました。" -ForegroundColor Green
        docker compose ps
    }
    else {
        Write-Host "エラー: ランナーの起動に失敗しました。" -ForegroundColor Red
        exit 1
    }
}

function Invoke-ComposeStop {
    Write-Host "ランナーを停止しています..." -ForegroundColor Yellow
    docker compose down
    if ($LASTEXITCODE -eq 0) {
        Write-Host "全ランナーを停止しました。" -ForegroundColor Green
    }
    else {
        Write-Host "エラー: ランナーの停止に失敗しました。" -ForegroundColor Red
        exit 1
    }
}

function Invoke-ComposeRestart {
    Invoke-ComposeStop
    Invoke-ComposeStart
}

function Invoke-ComposeStatus {
    if (-not (Test-DockerReady)) {
        Write-Host "Docker Desktopが起動していません。" -ForegroundColor Yellow
        return
    }
    docker compose ps
}

function Invoke-ComposeLogs {
    param([string[]]$ServiceNames)

    if (-not (Test-DockerReady)) {
        Write-Host "Docker Desktopが起動していません。" -ForegroundColor Yellow
        return
    }

    if ($ServiceNames -and $ServiceNames.Count -gt 0) {
        docker compose logs -f @ServiceNames
    }
    else {
        docker compose logs -f
    }
}

function Invoke-ComposeClean {
    Write-Host "警告: 全ランナーを停止し、キャッシュボリュームを全削除します。" -ForegroundColor Red
    $confirm = Read-Host "続行しますか？ (y/N)"
    if ($confirm -ne "y") {
        Write-Host "キャンセルしました。" -ForegroundColor Yellow
        return
    }
    docker compose down -v
    if ($LASTEXITCODE -eq 0) {
        Write-Host "全ランナーの停止とキャッシュ削除が完了しました。" -ForegroundColor Green
    }
    else {
        Write-Host "エラー: クリーン処理に失敗しました。" -ForegroundColor Red
        exit 1
    }
}

function Show-Usage {
    Write-Host @"
GitHub Actions セルフホステッドランナー管理スクリプト

使い方: .\runner.ps1 <コマンド> [オプション]

コマンド:
  start              ランナーを起動（Docker Desktop自動起動）
  stop               ランナーを停止（GitHub登録自動解除）
  restart            ランナーを再起動
  status             ランナーの状態を表示
  logs [サービス名]  ログを表示（サービス名省略で全体）
  clean              停止 + キャッシュボリューム全削除
  help               このヘルプを表示
"@
}

# メイン処理
Push-Location $PSScriptRoot
try {
    switch ($Command) {
        "start"   { Invoke-ComposeStart }
        "stop"    { Invoke-ComposeStop }
        "restart" { Invoke-ComposeRestart }
        "status"  { Invoke-ComposeStatus }
        "logs"    { Invoke-ComposeLogs -ServiceNames $Args }
        "clean"   { Invoke-ComposeClean }
        "help"    { Show-Usage }
    }
}
finally {
    Pop-Location
}
