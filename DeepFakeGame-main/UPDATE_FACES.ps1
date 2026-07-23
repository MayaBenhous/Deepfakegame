$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$facesRoot = Join-Path $projectRoot "faces"
$realRoot = Join-Path $facesRoot "real"
$fakeRoot = Join-Path $facesRoot "fake"
$manifestPath = Join-Path $facesRoot "faces.js"
$allowedExtensions = @(".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif")

function Convert-ToFaceUrl([System.IO.FileInfo]$file) {
    $relativePath = $file.FullName.Substring($facesRoot.Length).TrimStart('\', '/')
    $safeSegments = @($relativePath -split '[\\/]' | ForEach-Object { [Uri]::EscapeDataString($_) })
    "faces/$($safeSegments -join '/')"
}

function Get-FacePaths([string]$folder, [bool]$recursive = $false) {
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }

    $searchOptions = @{ LiteralPath = $folder; File = $true }
    if ($recursive) { $searchOptions.Recurse = $true }

    @(Get-ChildItem @searchOptions |
        Where-Object { $allowedExtensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name |
        ForEach-Object { Convert-ToFaceUrl $_ })
}

$realFaces = @(Get-FacePaths $realRoot)
$fakeGroups = [ordered]@{}

Get-ChildItem -LiteralPath $fakeRoot -Directory | Sort-Object Name | ForEach-Object {
    $fakeGroups[$_.Name] = @(Get-FacePaths $_.FullName $true)
}

$manifest = [ordered]@{
    real = $realFaces
    fakeGroups = $fakeGroups
}
$manifestJson = ConvertTo-Json -InputObject $manifest -Depth 5

$content = @"
// Generated automatically. Run UPDATE_FACES.bat after adding or removing images.
window.FACE_LIBRARY = $manifestJson;
"@

Set-Content -LiteralPath $manifestPath -Value $content -Encoding UTF8

Write-Host "Face list updated:" -ForegroundColor Green
Write-Host "  Real faces: $($realFaces.Count)"
$fakeGroups.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key) attack: $(@($_.Value).Count)"
}
Write-Host ""

$readyGroups = @($fakeGroups.GetEnumerator() | Where-Object { @($_.Value).Count -ge 2 })
if ($realFaces.Count -lt 3 -or $readyGroups.Count -lt 3) {
    Write-Host "The game needs at least 3 real faces and 3 attack folders with at least 2 fake faces each." -ForegroundColor Yellow
    Write-Host "It will stay in demo mode until the folders have enough images." -ForegroundColor Yellow
}
