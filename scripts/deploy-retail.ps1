# Copies this BOLT checkout (the WoW: Forever one, where BOLT is built) into the Retail
# install's AddOns folder, so Retail always runs the latest shipped version.
# Run from anywhere: powershell -ExecutionPolicy Bypass -File scripts\deploy-retail.ps1
# The Retail install is the World of Warcraft folder whose .build.info says product "wow"
# (Forever's says "wowf"); pass -RetailRoot to point at another one.
param([string]$RetailRoot)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot

function Test-RetailInstall([string]$root) {
    $info = Join-Path $root '.build.info'
    if (-not (Test-Path $info)) { return $false }
    $lines = Get-Content $info
    $cols = $lines[0].Split('|') | ForEach-Object { $_.Split('!')[0] }
    $productCol = [array]::IndexOf($cols, 'Product')
    $activeCol = [array]::IndexOf($cols, 'Active')
    foreach ($line in $lines | Select-Object -Skip 1) {
        $f = $line.Split('|')
        if ($f[$productCol] -eq 'wow' -and $f[$activeCol] -eq '1') { return $true }
    }
    return $false
}

if (-not $RetailRoot) {
    $candidates = @('D:\World of Warcraft', 'C:\Program Files (x86)\World of Warcraft',
                    'C:\Program Files\World of Warcraft', 'E:\World of Warcraft')
    $RetailRoot = $candidates | Where-Object { Test-RetailInstall $_ } | Select-Object -First 1
    if (-not $RetailRoot) { throw 'No Retail install found (no .build.info with product "wow"). Pass -RetailRoot.' }
}

$dest = Join-Path $RetailRoot '_retail_\Interface\AddOns\BOLT'
New-Item -ItemType Directory -Force $dest | Out-Null

# Same file set the CurseForge package ships (see .pkgmeta), mirrored: files gone from the
# source are removed from Retail too. Saved settings live in WTF, so they are untouched.
robocopy $source $dest /MIR /NFL /NDL /NJH /NP `
    /XD .git .github .vscode .release scripts `
    /XF .git .gitignore .pkgmeta README.md copilot-instructions.md *.zip | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

# Ship the real version number instead of the packager placeholder, so /bolt shows it.
$version = (git -C $source describe --tags --abbrev=0 2>$null)
if ($version) {
    $toc = Join-Path $dest 'BOLT.toc'
    # No BOM: a BOM before "## Interface" can make WoW misread the TOC as out of date.
    $text = [IO.File]::ReadAllText($toc) -replace '@project-version@', $version
    [IO.File]::WriteAllText($toc, $text, (New-Object Text.UTF8Encoding($false)))
}

Write-Output "BOLT $version copied to $dest"
