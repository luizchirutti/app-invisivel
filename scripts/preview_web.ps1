param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

Write-Host 'Starting iPhone visual preview (web mode)...' -ForegroundColor Yellow

$usePuro = $false

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Get-Command puro -ErrorAction SilentlyContinue) {
        $usePuro = $true
        Write-Host 'Flutter command not in PATH; using fallback: puro flutter' -ForegroundColor Yellow
    } else {
        Write-Host 'Flutter not found in PATH.' -ForegroundColor Red
        Write-Host 'Install Flutter and add <flutter_install>\bin to PATH, then reopen PowerShell.' -ForegroundColor Yellow
        Write-Host 'Quick check: where.exe flutter'
        exit 1
    }
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

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$ipv4 = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
    Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $ipv4) { $ipv4 = 'localhost' }

Write-Host ''
Write-Host '1) Running pub get...' -ForegroundColor Cyan
Invoke-Flutter 'pub' 'get'
if ($LASTEXITCODE -ne 0) { Write-Host 'pub get failed.' -ForegroundColor Red; exit $LASTEXITCODE }

$webDir = Join-Path $projectRoot 'build\web'
$port = 8080

if (-not $SkipBuild) {
    Write-Host ''
    Write-Host '2) Building Flutter web app (static files)...' -ForegroundColor Cyan
    Invoke-Flutter 'build' 'web' '--no-tree-shake-icons'
    if ($LASTEXITCODE -ne 0) { Write-Host 'flutter build web failed.' -ForegroundColor Red; exit $LASTEXITCODE }
} else {
    Write-Host ''
    Write-Host '2) Skipping build (using existing build\web)...' -ForegroundColor Cyan
    if (-not (Test-Path (Join-Path $webDir 'index.html'))) {
        Write-Host 'build\web\index.html not found. Run without -SkipBuild first.' -ForegroundColor Red
        exit 1
    }
}

function Start-ListenerWithFallback {
    param(
        [int]$PreferredPort,
        [string[]]$Prefixes
    )

    $portsToTry = @($PreferredPort, 8081, 8082, 8090)
    foreach ($candidatePort in $portsToTry) {
        foreach ($prefixTemplate in $Prefixes) {
            $prefix = $prefixTemplate -f $candidatePort
            try {
                $l = [System.Net.HttpListener]::new()
                $l.Prefixes.Add($prefix)
                $l.Start()
                return [PSCustomObject]@{
                    Listener = $l
                    Port = $candidatePort
                    Prefix = $prefix
                }
            } catch {
                if ($l) {
                    try { $l.Stop() } catch {}
                }
            }
        }
    }

    throw 'Failed to start HTTP listener on any fallback prefix/port.'
}

Write-Host ''
Write-Host "3) Starting HTTP server on port $port..." -ForegroundColor Cyan
Write-Host "Open this URL on your iPhone Safari (same Wi-Fi): http://$ipv4`:$port" -ForegroundColor Green
Write-Host 'Keep this terminal running while you test. Press Ctrl+C to stop.' -ForegroundColor Yellow
Write-Host ''

# Simple PowerShell HTTP file server
$listener = $null
$boundPrefix = $null
$boundPort = $port
$prefixes = @("http://localhost:{0}/", "http://127.0.0.1:{0}/")
try {
    # Try binding to all interfaces (requires admin or URL ACL)
    $listenerAll = [System.Net.HttpListener]::new()
    $listenerAll.Prefixes.Add("http://+:$port/")
    $listenerAll.Start()
    $listenerAll.Stop()
    # If we got here, we have permission – prefer all-interfaces binding
    $prefixes = @("http://+:{0}/", "http://localhost:{0}/", "http://127.0.0.1:{0}/")
} catch {
    Write-Host "Note: binding to all interfaces failed (no admin rights); server is localhost-only." -ForegroundColor Yellow
    Write-Host "To access from iPhone, run this terminal as Administrator, or use: netsh http add urlacl url=http://+:8080/ user=$env:USERNAME" -ForegroundColor Yellow
    Write-Host "Alternatively open http://localhost:$port on THIS machine to verify the build." -ForegroundColor Cyan
}

$listenerInfo = Start-ListenerWithFallback -PreferredPort $port -Prefixes $prefixes
$listener = $listenerInfo.Listener
$boundPrefix = $listenerInfo.Prefix
$boundPort = $listenerInfo.Port

if ($boundPort -ne $port) {
    Write-Host "Port $port was unavailable; switched to $boundPort." -ForegroundColor Yellow
}

if ($boundPrefix -like 'http://+*') {
    Write-Host "Server running at http://$ipv4`:$boundPort (or http://localhost:$boundPort)" -ForegroundColor Green
} else {
    Write-Host "Server running at http://localhost:$boundPort" -ForegroundColor Green
    Write-Host "Current binding: $boundPrefix" -ForegroundColor Cyan
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response

        $localPath = $req.Url.LocalPath -replace '/', '\'
        if ($localPath -eq '\') { $localPath = '\index.html' }
        $filePath = Join-Path $webDir $localPath.TrimStart('\')

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = switch ($ext) {
                '.html' { 'text/html; charset=utf-8' }
                '.js'   { 'application/javascript' }
                '.css'  { 'text/css' }
                '.json' { 'application/json' }
                '.png'  { 'image/png' }
                '.ico'  { 'image/x-icon' }
                '.wasm' { 'application/wasm' }
                default { 'application/octet-stream' }
            }
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $res.ContentType = $mime
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            # SPA fallback: serve index.html
            $index = Join-Path $webDir 'index.html'
            if (Test-Path $index) {
                $bytes = [System.IO.File]::ReadAllBytes($index)
                $res.ContentType = 'text/html; charset=utf-8'
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $res.StatusCode = 404
            }
        }
        $res.OutputStream.Close()
    } catch [System.Net.HttpListenerException] {
        break
    } catch {
        $requestPath = $null
        if ($req -and $req.Url) {
            $requestPath = $req.Url.AbsoluteUri
        }
        Write-Host "[HTTP 500] Request: $requestPath" -ForegroundColor Red
        Write-Host "[HTTP 500] Error: $($_.Exception.Message)" -ForegroundColor Red
        try { $ctx.Response.StatusCode = 500; $ctx.Response.OutputStream.Close() } catch {}
    }
}

$listener.Stop()
