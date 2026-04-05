param(
    [string]$InputFile = ''
)

# Resolve paths relative to script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }

# Editable directories (change here if you want different locations)
$inDir = Join-Path $scriptDir 'in'
$outDir = Join-Path $scriptDir 'ms-rust'

# Helper: produce a short relative path for nicer output
function Get-ShortPath([string]$path) {
    try {
        if ($null -ne $path -and $path.StartsWith($scriptDir)) {
            $rel = $path.Substring($scriptDir.Length)
            if ($rel.StartsWith('\') -or $rel.StartsWith('/')) { $rel = $rel.Substring(1) }
            return $rel
        }
    } catch { }
    return $path
}

# Determine input path
if (-not $InputFile) {
    $inputPath = Join-Path $inDir 'all.txt'
    if (-not (Test-Path $inputPath)) {
        Write-Error "Default input file not found: $inputPath"
        exit 1
    }
} else {
    if (Test-Path $InputFile) {
        $inputPath = (Resolve-Path -LiteralPath $InputFile).ProviderPath
    } else {
        # Try in/ directory and common extensions
        $candidate = Join-Path $inDir $InputFile
        if (Test-Path $candidate) { $inputPath = $candidate }
        else {
            $found = $false
            foreach ($ext in @('.txt', '.md')) {
                $try = $candidate + $ext
                if (Test-Path $try) { $inputPath = $try; $found = $true; break }
            }
            if (-not $found) {
                Write-Error "Input file not found: tried '$InputFile' and 'in\$InputFile(.txt|.md)'"
                exit 1
            }
        }
    }
}

# If out/ exists, clear its contents; otherwise create it
if (Test-Path $outDir) {
    try {
        Get-ChildItem -Path $outDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning ("Failed to fully clear {0}: {1}" -f $outDir, $_)
    }
} else {
    New-Item -Path $outDir -ItemType Directory | Out-Null
}

$content = Get-Content -Raw -LiteralPath $inputPath -ErrorAction Stop
$lines = [System.Text.RegularExpressions.Regex]::Split($content, "\r?\n")

# Find separator lines that start with three dashes (pattern '^---')
$sepIndices = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^---') { $sepIndices += $i }
}

if ($sepIndices.Count -lt 2) {
    Write-Host "No section separators ('---') found or only one; nothing to extract."
    exit 0
}

$fileCounter = 1

# For each pair of separators, extract the section between them
for ($k = 0; $k -lt ($sepIndices.Count - 1); $k++) {
    $startIdx = $sepIndices[$k] + 1
    $endIdx = $sepIndices[$k + 1] - 1
    if ($endIdx -lt $startIdx) { continue } # empty section between separators

    $sectionLines = $lines[$startIdx..$endIdx]

    # Find H1 headings inside this section
    $localH1 = @()
    for ($j = 0; $j -lt $sectionLines.Length; $j++) {
        if ($sectionLines[$j] -match '^[ \t]*#\s+') { $localH1 += $j }
    }

    if ($localH1.Count -eq 0) { continue } # no H1 in this section

    # Use only the first H1 in the section: extract from that H1 to the end of the section
    if ($localH1.Count -gt 0) {
        $relStart = $localH1[0]
        $relEnd = $sectionLines.Length - 1

        $extractLines = $sectionLines[$relStart..$relEnd]

        # Remove any lines that start with '---' (defensive)
        $extractLines = $extractLines | Where-Object { -not ($_ -match '^---') }

        # Get title from first line
        $titleLine = $extractLines[0] -replace '^[ \t]*#\s+','' -replace '\s+$',''
        # Normalize and sanitize filename base:
        # - lowercase, trim
        # - replace one-or-more spaces or '/' by a single '_'
        # - replace any run of other disallowed chars by a single '_'
        # - trim leading/trailing underscores
        $filenameBase = $titleLine.Trim().ToLower()
        $filenameBase = $filenameBase -replace '[\s/]+', '_'
        $filenameBase = $filenameBase -replace '[^a-z0-9_]+', '_'
        $filenameBase = $filenameBase.TrimStart('_').TrimEnd('_')
        if ([string]::IsNullOrWhiteSpace($filenameBase)) { $filenameBase = 'section' }

        $index = $fileCounter.ToString('00')
        $outName = "${index}_${filenameBase}.md"
        $outPath = Join-Path $outDir $outName

        # Write file (even if extractLines is empty, write an empty file)
        if ($extractLines.Count -eq 0) { "" | Out-File -FilePath $outPath -Encoding UTF8 }
        else { $extractLines | Out-File -FilePath $outPath -Encoding UTF8 }

        $shortOut = Get-ShortPath $outPath
        Write-Host "Wrote: $shortOut"
        $fileCounter++
    }
}

    $shortOutDir = Get-ShortPath $outDir
    Write-Host "Done. Generated $(( $fileCounter - 1 )) file(s) in: $shortOutDir"

# Copy SKILL.md from input directory to output directory, if present
$skillSrc = Join-Path $inDir 'SKILL.md'
$skillDst = Join-Path $outDir 'SKILL.md'
if (Test-Path $skillSrc) {
    try {
        Copy-Item -LiteralPath $skillSrc -Destination $skillDst -Force -ErrorAction Stop
        $shortSkillDst = Get-ShortPath $skillDst
        $shortSkillSrc = Get-ShortPath $skillSrc
        Write-Host "Copied SKILL.md from: $shortSkillSrc to: $shortSkillDst"
    } catch {
        Write-Warning ("Failed to copy SKILL.md from {0} to {1}: {2}" -f (Get-ShortPath $skillSrc), (Get-ShortPath $skillDst), $_)
    }
} else {
    Write-Warning ("Source SKILL.md not found at: {0}" -f (Get-ShortPath $skillSrc))
}

# Inform the user (US English) — highlighted
$shortSkillDst2 = Get-ShortPath $skillDst
Write-Host -ForegroundColor Yellow "Please review and adjust the contents of '$shortSkillDst2' as needed."
Write-Host -ForegroundColor Green "Once satisfied, copy $shortOutDir/ directory in %USERPROFILE%/.claude/skills/ directory."
