[CmdletBinding()]
param(
    [string]$InputFile = '',
    [switch]$Help
)

if ($Help) {
    Write-Host @'
USAGE
  new-skill.ps1 [-InputFile <path>] [-Help] [-Verbose]

  -InputFile  Path to source text file (default: in\all.txt)
  -Help       Show this help message
  -Verbose    Print extra diagnostic output

DESCRIPTION
  Splits all.txt into numbered Markdown files under ms-rust\,
  applies tag conversions and image-to-text patches, then copies SKILL.md.
'@
    exit 0
}

# Resolve paths relative to script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }

# Editable directories (change here if you want different locations)
$inDir = Join-Path $scriptDir 'in'
$outDir = Join-Path $scriptDir 'ms-rust'

# ===========================================================================
# CONFIGURATION -- image-to-text replacement rules
# ===========================================================================
# To add a new replacement in the future:
#   1. Append a new hashtable to $ImageReplacements below.
#   2. Set File to the exact output filename (e.g. '03_documentation.md').
#   3. Set Old to the exact text to find (use @'...'@ for multi-line).
#   4. Set New to the replacement text   (use @'...'@ for multi-line).
# ===========================================================================
$ImageReplacements = @(
    @{
        File = '10_libraries_interoperability_guidelines.md'
        Old  = @'
>
> <div style="background-color:white;">
>
> ![TEXT](M-TYPES-SEND.png)
>
> </div>
'@
        New  = '<!-- Read the violin diagram online at: https://microsoft.github.io/rust-guidelines/guidelines/libs/interop/index.html -->'
    },
    @{
        File = '03_documentation.md'
        Old  = '![TEXT](M-DOC-INLINE_BAD.png)'
        New  = @'
```
Re-Exports
----------
pub use view::*;
```
'@
    },
    @{
        File = '03_documentation.md'
        Old  = '![TEXT](M-DOC-INLINE_GOOD.png)'
        New  = @'
```
View -- A view over a configuration of type T, containing data for a specific context.
```
'@
    },
    @{
        File = '03_documentation.md'
        Old  = '![TEXT](M-FIRST-DOC-SENTENCE_GOOD.png)'
        New  = @'
| Module     | Description                                                                 |
|------------|-----------------------------------------------------------------------------|
| alloc      | Memory allocation APIs.                                                     |
| any        | Utilities for dynamic typing or type reflection.                            |
| arch       | SIMD and vendor intrinsics module.                                          |
| array      | Utilities for the array primitive type.                                     |
| ascii      | Operations on ASCII strings and characters.                                 |
| backtrace  | Support for capturing a stack backtrace of an OS thread.                    |
| borrow     | A module for working with borrowed data.                                    |
| boxed      | The `Box<T>` type for heap allocation.                                      |
| cell       | Shareable mutable containers.                                               |
| char       | Utilities for the `char` primitive type.                                    |
| clone      | The `Clone` trait for types that cannot be 'implicitly copied'.             |
| cmp        | Utilities for comparing and ordering values.                                |
'@
    },
    @{
        File = '03_documentation.md'
        Old  = '![TEXT](M-FIRST-DOC-SENTENCE_BAD.png)'
        New  = @'
| Item                          | Description                                                                 |
|-------------------------------|-----------------------------------------------------------------------------|
| DuplicateKeysError            | If you try to merge two Contexts together which have duplicate keys, this is the error you get. |
| Fragment                      | Contains a single layer of configuration data (from one source) which can be merged with data from other sources to yield a merged fragment to be deserialized into a concrete configuration type. |
| InternalContractViolationError| An error that signals some internal API contract or logical precondition was violated. |
| MergedContext                 |                                                                             |
| Snapshot                      | A snapshot of a config value T, allowing the value to be read. This type transparently takes care of resource management concerns required to expose the values efficiently. |
| View                          | A view over a configuration of type T, containing data for a specific context. |
'@
    }
)

# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================

# Produce a short relative path for nicer output
function Get-ShortPath([string]$path) {
    try {
        if ($null -ne $path -and $path.StartsWith($scriptDir)) {
            $rel = $path.Substring($scriptDir.Length)
            if ($rel.StartsWith('\') -or $rel.StartsWith('/')) { $rel = $rel.Substring(1) }
            return $rel
        }
    }
    catch { }
    return $path
}

# Apply all entries in $ImageReplacements to files in $targetDir.
# Normalizes line endings to LF for matching, then writes back with CRLF.
function Invoke-ImageReplacements {
    param([string]$targetDir)

    foreach ($rule in $ImageReplacements) {
        $filePath = Join-Path $targetDir $rule.File
        if (-not (Test-Path $filePath)) {
            Write-Warning "Replacement target not found: $($rule.File) -- skipping"
            continue
        }

        $raw = Get-Content -Raw -LiteralPath $filePath
        $rawLF = $raw -replace '\r\n', "`n" -replace '\r', "`n"
        # Trim trailing newlines that PowerShell here-strings always append,
        # so surrounding line endings in the file are not consumed.
        $oldLF = ($rule.Old -replace '\r\n', "`n" -replace '\r', "`n").TrimEnd("`n")
        $newLF = ($rule.New -replace '\r\n', "`n" -replace '\r', "`n").TrimEnd("`n")

        if (-not $rawLF.Contains($oldLF)) {
            $preview = ($oldLF -split "`n")[0]
            Write-Warning ("Pattern not found in {0}: {1}" -f $rule.File, $preview)
            continue
        }

        $resultLF = $rawLF.Replace($oldLF, $newLF)
        $result = $resultLF -replace "`n", "`r`n"
        [System.IO.File]::WriteAllText($filePath, $result, [System.Text.Encoding]::UTF8)
        Write-Host ("  patched: {0} (replaced: {1})" -f $rule.File, ($oldLF -split "`n")[0])
    }
}

function ConvertFrom-WhyTag([string]$text) {
    return [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        '<why>(.*?)</why>',
        'Why this version exists: $1',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
}

function ConvertFrom-VersionTag([string]$text) {
    return [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        '<version>([\d.]+)</version>',
        'Version: $1'
    )
}

# Removes mdBook anchor suffixes of the form: (xxx) { #xxx }
# Spaces inside parentheses/braces are tolerated; the id must match the label.
function Remove-AnchorSuffix([string]$text) {
    return [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        '\(\s*(\S+?)\s*\)\s*\{\s*#\1\s*\}'
        , ''
    )
}

# Removes external hyperlinks [text](https://...).
# Lines whose only content is a link (+ optional trailing , . and) are deleted entirely.
# Inline links embedded in prose keep their anchor text.
# Cleans up empty parentheses () and orphaned "Follow" left alone on a line.
#
# NOTE: all patterns use the negative lookbehind (?<!!) to exclude markdown image syntax
# ![alt](src). Image links such as ![TEXT](M-DOC-INLINE_BAD.png) must be left intact at
# this stage because Invoke-ImageReplacements replaces them later on the written files.
function Remove-ExternalLinks([string]$text) {
    $opts = [System.Text.RegularExpressions.RegexOptions]::Multiline
    # Pass 1: delete lines that are nothing but a link + optional punctuation
    $result = [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        '^\s*(?<!!)\[[^\]]+\]\(https?://[^)]+\)\s*(?:,?\s*(?:and\s*)?)?\s*[.,]?\s*$',
        '',
        $opts
    )
    # Pass 2: inline links still present -- keep anchor text, drop URL
    $result = [System.Text.RegularExpressions.Regex]::Replace(
        $result,
        '(?<!!)\[([^\]]+)\]\(https?://[^)]+\)',
        '$1'
    )
    $result = [System.Text.RegularExpressions.Regex]::Replace($result, '\(\s*\)', '')
    $result = [System.Text.RegularExpressions.Regex]::Replace($result, '^\s*Follow\s*$', '', $opts)
    return $result
}

# Removes relative/internal links [text](path).
# Lines whose only content is a link (+ optional trailing , . and) are deleted entirely.
# Inline links embedded in prose keep their anchor text.
# Cleans up empty parentheses () and orphaned "Follow" left alone on a line.
#
# NOTE: all patterns use the negative lookbehind (?<!!) to exclude markdown image syntax
# ![alt](src). Image links such as ![TEXT](M-DOC-INLINE_BAD.png) must be left intact at
# this stage because Invoke-ImageReplacements replaces them later on the written files.
function Remove-RelativeLinks([string]$text) {
    $opts = [System.Text.RegularExpressions.RegexOptions]::Multiline
    # Pass 1: delete lines that are nothing but a link + optional punctuation
    $result = [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        '^\s*(?<!!)\[[^\]]+\]\((?!https?://)[^)]+\)\s*(?:,?\s*(?:and\s*)?)?\s*[.,]?\s*$',
        '',
        $opts
    )
    # Pass 2: inline links still present -- keep anchor text, drop URL
    $result = [System.Text.RegularExpressions.Regex]::Replace(
        $result,
        '(?<!!)\[([^\]]+)\]\((?!https?://)[^)]+\)',
        '$1'
    )
    $result = [System.Text.RegularExpressions.Regex]::Replace($result, '\(\s*\)', '')
    $result = [System.Text.RegularExpressions.Regex]::Replace($result, '^\s*Follow\s*$', '', $opts)
    return $result
}

# ===========================================================================
# MAIN -- entry point
# ===========================================================================

# Determine input path
if (-not $InputFile) {
    $inputPath = Join-Path $inDir 'all.txt'
    if (-not (Test-Path $inputPath)) {
        Write-Error "Default input file not found: $inputPath"
        exit 1
    }
}
else {
    if (Test-Path $InputFile) {
        $inputPath = (Resolve-Path -LiteralPath $InputFile).ProviderPath
    }
    else {
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
    }
    catch {
        Write-Warning ("Failed to fully clear {0}: {1}" -f $outDir, $_)
    }
}
else {
    try {
        New-Item -Path $outDir -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Cannot create output directory '$outDir': $_"
        exit 1
    }
}

$content = Get-Content -Raw -LiteralPath $inputPath -ErrorAction Stop
$content = ConvertFrom-WhyTag $content
Write-Verbose "Applied ConvertFrom-WhyTag"
$content = ConvertFrom-VersionTag $content
Write-Verbose "Applied ConvertFrom-VersionTag"
$content = Remove-AnchorSuffix $content
Write-Verbose "Applied Remove-AnchorSuffix"
$content = Remove-ExternalLinks $content
Write-Verbose "Applied Remove-ExternalLinks"
$content = Remove-RelativeLinks $content
Write-Verbose "Applied Remove-RelativeLinks"
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
        $titleLine = $extractLines[0] -replace '^[ \t]*#+\s+', '' -replace '\s+$', ''
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
        try {
            if ($extractLines.Count -eq 0) {
                "" | Out-File -FilePath $outPath -Encoding UTF8 -ErrorAction Stop
            }
            else {
                $extractLines | Out-File -FilePath $outPath -Encoding UTF8 -ErrorAction Stop
            }
        }
        catch {
            Write-Warning "Failed to write '$outName': $_"
            continue
        }

        $shortOut = Get-ShortPath $outPath
        Write-Host "Wrote: $shortOut"
        $fileCounter++
    }
}

$shortOutDir = Get-ShortPath $outDir
Write-Host "Done. Generated $(( $fileCounter - 1 )) file(s) in: $shortOutDir"

# Apply image-to-text replacements
Write-Host "Applying image-to-text replacements..."
Invoke-ImageReplacements -targetDir $outDir
Write-Host "Replacements done."

# Copy SKILL.md from input directory to output directory, if present
$skillSrc = Join-Path $inDir 'SKILL.md'
$skillDst = Join-Path $outDir 'SKILL.md'
if (Test-Path $skillSrc) {
    try {
        Copy-Item -LiteralPath $skillSrc -Destination $skillDst -Force -ErrorAction Stop
        $shortSkillDst = Get-ShortPath $skillDst
        $shortSkillSrc = Get-ShortPath $skillSrc
        Write-Host "Copied SKILL.md from: $shortSkillSrc to: $shortSkillDst"
    }
    catch {
        Write-Warning ("Failed to copy SKILL.md from {0} to {1}: {2}" -f (Get-ShortPath $skillSrc), (Get-ShortPath $skillDst), $_)
    }
}
else {
    Write-Warning ("Source SKILL.md not found at: {0}" -f (Get-ShortPath $skillSrc))
}

# Inform the user (US English) — highlighted
$shortSkillDst2 = Get-ShortPath $skillDst
Write-Host -ForegroundColor Yellow "Please review and adjust the contents of '$shortSkillDst2' as needed."
Write-Host -ForegroundColor Green "Once satisfied, copy $shortOutDir/ directory in %USERPROFILE%/.claude/skills/ directory."
