param(
    [switch]$SkipPubGet,
    [switch]$SkipBuild
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

Write-Host "Iniciando preflight maximo (sem dispositivo)..." -ForegroundColor Yellow

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Get-Command puro -ErrorAction SilentlyContinue) {
        $usePuro = $true
        Write-Host "Flutter command not in PATH; usando fallback: puro flutter" -ForegroundColor Yellow
    } else {
        Write-Host "Flutter nao encontrado no PATH." -ForegroundColor Red
        exit 1
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Invoke-Step -Name 'Flutter version' -Command { Invoke-Flutter '--version' }

if (-not $SkipPubGet) {
    Invoke-Step -Name 'Pub get' -Command { Invoke-Flutter 'pub' 'get' }
}

Invoke-Step -Name 'Static analysis (errors only)' -Command {
    Invoke-Flutter 'analyze' '--no-fatal-infos' '--no-fatal-warnings'
}
Invoke-Step -Name 'Preflight security config test' -Command {
    Invoke-Flutter 'test' 'test/security/preflight_security_configuration_test.dart'
}
Invoke-Step -Name 'Full test suite' -Command { Invoke-Flutter 'test' }

if (-not $SkipBuild) {
    Invoke-Step -Name 'Android debug build (APK)' -Command { Invoke-Flutter 'build' 'apk' '--debug' }
} else {
    Write-Host "Build step pulado por parametro -SkipBuild" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Preflight maximo concluido com sucesso." -ForegroundColor Green
Write-Host "Observacao: build iOS nativo requer macOS/Xcode; neste ambiente foi validado via testes estaticos e Flutter." -ForegroundColor Yellow
exit 0
