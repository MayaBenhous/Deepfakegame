param(
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

$gameRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$listener = $null
$selectedPort = $null

foreach ($candidatePort in 8000..8010) {
    $candidateListener = $null
    try {
        $candidateListener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback,
            $candidatePort
        )
        $candidateListener.Start()
        $listener = $candidateListener
        $selectedPort = $candidatePort
        break
    }
    catch {
        if ($candidateListener) {
            try { $candidateListener.Stop() } catch {}
        }
    }
}

if (-not $listener) {
    throw "Could not find a free local port between 8000 and 8010."
}

function Get-ContentType {
    param([string]$Extension)

    switch ($Extension.ToLowerInvariant()) {
        ".html"  { return "text/html; charset=utf-8" }
        ".js"    { return "text/javascript; charset=utf-8" }
        ".css"   { return "text/css; charset=utf-8" }
        ".json"  { return "application/json; charset=utf-8" }
        ".png"   { return "image/png" }
        ".jpg"   { return "image/jpeg" }
        ".jpeg"  { return "image/jpeg" }
        ".gif"   { return "image/gif" }
        ".webp"  { return "image/webp" }
        ".avif"  { return "image/avif" }
        ".svg"   { return "image/svg+xml" }
        ".ttf"   { return "font/ttf" }
        ".woff"  { return "font/woff" }
        ".woff2" { return "font/woff2" }
        default  { return "application/octet-stream" }
    }
}

function Find-Browser {
    $browserCandidates = @(
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($candidate in $browserCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Find-UsbSerialPort {
    try {
        $usbPort = Get-CimInstance Win32_SerialPort |
            Where-Object {
                $_.PNPDeviceID -like "USB\*" -and
                $_.DeviceID -match "^COM\d+$"
            } |
            Select-Object -First 1

        if ($usbPort) {
            return $usbPort.DeviceID
        }
    }
    catch {
        # Fall back to the Windows serial-device map below.
    }

    try {
        $serialMap = Get-ItemProperty -LiteralPath "HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM"
        $usbEntry = $serialMap.PSObject.Properties |
            Where-Object {
                $_.Name -notlike "PS*" -and
                $_.Name -match "USB|VCP|ACM"
            } |
            Select-Object -First 1

        if ($usbEntry) {
            return [string]$usbEntry.Value
        }
    }
    catch {
        return $null
    }

    return $null
}

$serialPortName = Find-UsbSerialPort
$serialPort = $null
$serialBuffer = ""

if ($serialPortName) {
    try {
        $serialPort = [System.IO.Ports.SerialPort]::new($serialPortName, 9600)
        $serialPort.ReadTimeout = 50
        $serialPort.WriteTimeout = 250
        $serialPort.Open()
        Write-Host "Arduino connected on $serialPortName."

        # Opening a serial connection resets many Arduino boards.
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Warning "The USB serial device on $serialPortName could not be opened: $($_.Exception.Message)"
        if ($serialPort) {
            $serialPort.Dispose()
            $serialPort = $null
        }
    }
}
else {
    Write-Warning "No USB serial device was detected. Reconnect the Arduino and restart this launcher."
}

$gameUrl = "http://localhost:$selectedPort/index.html"
$browserPath = Find-Browser

Write-Host "DeepFake Game is running at $gameUrl"
Write-Host "Keep this window open while the game is running."
Write-Host "Press Ctrl+C to stop."

if (-not $NoBrowser) {
    if ($browserPath) {
        Start-Process -FilePath $browserPath -ArgumentList $gameUrl
    }
    else {
        Start-Process $gameUrl
        Write-Warning "Chrome or Edge was not found automatically. USB controller support requires Chrome or Edge."
    }
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 1000
            $stream.WriteTimeout = 1000
            $reader = [System.IO.StreamReader]::new(
                $stream,
                [System.Text.Encoding]::ASCII,
                $false,
                1024,
                $true
            )

            $requestLine = $reader.ReadLine()
            if (-not $requestLine) {
                continue
            }

            while ($true) {
                $headerLine = $reader.ReadLine()
                if ([string]::IsNullOrEmpty($headerLine)) {
                    break
                }
            }

            $requestParts = $requestLine.Split(" ")
            $method = $requestParts[0]
            $rawPath = if ($requestParts.Length -ge 2) { $requestParts[1] } else { "/" }
            $urlPath = [System.Uri]::UnescapeDataString(($rawPath.Split("?")[0]))

            if ($urlPath -eq "/controller/status") {
                $statusPayload = @{
                    connected = [bool]($serialPort -and $serialPort.IsOpen)
                    port = $serialPortName
                } | ConvertTo-Json -Compress
                $body = [System.Text.Encoding]::UTF8.GetBytes($statusPayload)
                $status = "200 OK"
                $contentType = "application/json; charset=utf-8"
            }
            elseif ($urlPath -eq "/controller/poll") {
                $messages = @()
                if ($serialPort -and $serialPort.IsOpen) {
                    try {
                        $serialBuffer += $serialPort.ReadExisting()
                        $serialLines = $serialBuffer -split "\r?\n"
                        if ($serialLines.Count -gt 1) {
                            $serialBuffer = $serialLines[-1]
                            $messages = @(
                                $serialLines[0..($serialLines.Count - 2)] |
                                    ForEach-Object { $_.Trim() } |
                                    Where-Object { $_ -match "^(?:[1-9]|SUBMIT|RESET)$" }
                            )
                        }
                    }
                    catch {
                        Write-Warning "Could not read from ${serialPortName}: $($_.Exception.Message)"
                    }
                }

                $pollPayload = @{
                    connected = [bool]($serialPort -and $serialPort.IsOpen)
                    messages = $messages
                } | ConvertTo-Json -Compress
                $body = [System.Text.Encoding]::UTF8.GetBytes($pollPayload)
                $status = "200 OK"
                $contentType = "application/json; charset=utf-8"
            }
            elseif ($urlPath -eq "/controller/signal") {
                $signalMatch = [System.Text.RegularExpressions.Regex]::Match(
                    $rawPath,
                    "(?:\?|&)value=([YGR])(?:&|$)",
                    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                )

                if ($signalMatch.Success -and $serialPort -and $serialPort.IsOpen) {
                    try {
                        $serialPort.Write($signalMatch.Groups[1].Value.ToUpperInvariant())
                        $body = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                        $status = "200 OK"
                    }
                    catch {
                        $body = [System.Text.Encoding]::UTF8.GetBytes('{"ok":false}')
                        $status = "503 Service Unavailable"
                    }
                }
                else {
                    $body = [System.Text.Encoding]::UTF8.GetBytes('{"ok":false}')
                    $status = "503 Service Unavailable"
                }
                $contentType = "application/json; charset=utf-8"
            }
            else {
                if ($urlPath -eq "/") {
                    $urlPath = "/index.html"
                }

                $relativePath = $urlPath.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)
                $requestedPath = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($gameRoot, $relativePath)
                )

                $insideGameRoot = $requestedPath.StartsWith(
                    $gameRoot + [System.IO.Path]::DirectorySeparatorChar,
                    [System.StringComparison]::OrdinalIgnoreCase
                )

                if (
                    ($method -ne "GET" -and $method -ne "HEAD") -or
                    -not $insideGameRoot -or
                    -not (Test-Path -LiteralPath $requestedPath -PathType Leaf)
                ) {
                    $body = [System.Text.Encoding]::UTF8.GetBytes("Not found")
                    $status = "404 Not Found"
                    $contentType = "text/plain; charset=utf-8"
                }
                else {
                    $body = [System.IO.File]::ReadAllBytes($requestedPath)
                    $status = "200 OK"
                    $contentType = Get-ContentType ([System.IO.Path]::GetExtension($requestedPath))
                }
            }

            $responseHeaders = (
                "HTTP/1.1 $status`r`n" +
                "Content-Type: $contentType`r`n" +
                "Content-Length: $($body.Length)`r`n" +
                "Cache-Control: no-cache`r`n" +
                "Connection: close`r`n`r`n"
            )
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($responseHeaders)
            $stream.Write($headerBytes, 0, $headerBytes.Length)

            if ($method -ne "HEAD") {
                $stream.Write($body, 0, $body.Length)
            }
            $stream.Flush()
        }
        catch {
            Write-Warning $_.Exception.Message
        }
        finally {
            $client.Close()
        }
    }
}
finally {
    $listener.Stop()
    if ($serialPort) {
        try {
            if ($serialPort.IsOpen) {
                $serialPort.Close()
            }
        }
        finally {
            $serialPort.Dispose()
        }
    }
}
