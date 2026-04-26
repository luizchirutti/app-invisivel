param(
    [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$usePuro = $false

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
    & $Command

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Name (exit code $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "OK: $Name" -ForegroundColor Green
}

function Invoke-Flutter {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$FlutterArgs
    )

    if ($usePuro) {
        & puro flutter @FlutterArgs
    } else {
        & flutter @FlutterArgs
    }
}

Write-Host "Starting quality check pipeline..." -ForegroundColor Yellow

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Get-Command puro -ErrorAction SilentlyContinue) {
        $usePuro = $true
        Write-Host "Flutter command not in PATH; using fallback: puro flutter" -ForegroundColor Yellow
    } else {
        Write-Host "Flutter not found in PATH." -ForegroundColor Red
        Write-Host "Install Flutter and add <flutter_install>\\bin to PATH, then re-open PowerShell." -ForegroundColor Yellow
        Write-Host "Quick check: where.exe flutter"
        exit 1
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Invoke-Step -Name 'Flutter version' -Command { Invoke-Flutter '--version' }

if (-not $SkipPubGet) {
    Invoke-Step -Name 'Pub get' -Command { Invoke-Flutter 'pub' 'get' }
}

Invoke-Step -Name 'Static analysis' -Command { Invoke-Flutter 'analyze' }

Invoke-Step -Name 'Domain usecases tests' -Command {
    Invoke-Flutter 'test' 'test/domain/usecases'
}

Invoke-Step -Name 'Data repositories tests' -Command {
    Invoke-Flutter 'test' 'test/data/repositories'
}

Invoke-Step -Name 'Platform services tests' -Command {
    Invoke-Flutter 'test' 'test/services/platform'
}

Invoke-Step -Name 'Presentation bloc tests' -Command {
    Invoke-Flutter 'test' 'test/presentation/bloc'
}

Invoke-Step -Name 'Presentation widgets tests' -Command {
    Invoke-Flutter 'test' 'test/presentation/widgets'
}

Invoke-Step -Name 'Presentation pages tests' -Command {
    Invoke-Flutter 'test' 'test/presentation/pages'
}

Invoke-Step -Name 'Full test suite' -Command { Invoke-Flutter 'test' }

Write-Host ""
Write-Host "Quality pipeline completed successfully." -ForegroundColor Green
exit 0
