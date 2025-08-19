$ErrorActionPreference = "Stop"

$albumUrl = 'https://imgur.com/a/potent-keefer-sprite-s-s-0vkBHMR'
$dest = 'C:\Users\quint\Desktop\AI_SLOP_SURVIVORS\BespokeAssetSources\kefir'

if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
Get-ChildItem -Path $dest -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

$tmpHtml = Join-Path $env:TEMP ('imgur_album_{0}.html' -f ([guid]::NewGuid().ToString('N')))
try {
    & curl.exe -L $albumUrl -o $tmpHtml | Out-Null
    $html = [System.IO.File]::ReadAllText($tmpHtml)

    $regex = 'https?://i\.imgur\.com/[A-Za-z0-9]+(?:\.(?:png|jpg|jpeg|gif))'
    $urls = [System.Text.RegularExpressions.Regex]::Matches($html, $regex) | ForEach-Object { $_.Value } | Select-Object -Unique

    if (-not $urls -or $urls.Count -lt 1) {
        Write-Error 'No direct image URLs found in the Imgur album HTML.'
    }

    $targetNames = @('kefiridle.png','kefirwalk1.png','kefirwalk2.png')
    $max = [Math]::Min($targetNames.Count, $urls.Count)

    try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop } catch { }

    for ($i = 0; $i -lt $max; $i++) {
        $u = $urls[$i]
        $tmpImg = Join-Path $env:TEMP ('kefir_{0}{1}' -f $i, [System.IO.Path]::GetExtension($u))
        & curl.exe -L $u -o $tmpImg | Out-Null

        $outPath = Join-Path $dest $targetNames[$i]
        $converted = $false
        try {
            $img = [System.Drawing.Image]::FromFile($tmpImg)
            $img.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $img.Dispose()
            $converted = $true
        } catch {
            # Fallback: just copy
        }
        if (-not $converted) { Copy-Item $tmpImg $outPath -Force }
        Remove-Item $tmpImg -Force -ErrorAction SilentlyContinue
    }

    Write-Output ('Saved: ' + ((Get-ChildItem $dest | Select-Object -ExpandProperty Name) -join ', '))
}
finally {
    Remove-Item $tmpHtml -Force -ErrorAction SilentlyContinue
}


