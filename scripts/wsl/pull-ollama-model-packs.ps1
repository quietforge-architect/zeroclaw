#Requires -Version 7.0
<#
.SYNOPSIS
    Pulls recommended Ollama model packs via WSL-native ollama CLI.

.DESCRIPTION
    Provides a model suitability matrix for:
      - dev
      - debugging
      - business writing
      - creative writing
      - organizing/planning

    Uses WSL ollama binary (not Windows) for all pull operations.

.EXAMPLE
    .\pull-ollama-model-packs.ps1 -ListOnly

.EXAMPLE
    .\pull-ollama-model-packs.ps1 -Pack Starter

.EXAMPLE
    .\pull-ollama-model-packs.ps1 -Pack BusinessCreative

.EXAMPLE
    .\pull-ollama-model-packs.ps1 -CustomModels qwen2.5-coder,deepseek-r1:8b
#>

param(
    [ValidateSet('Starter', 'DeveloperDebug', 'BusinessCreative', 'All')]
    [string]$Pack = 'Starter',

    [string[]]$CustomModels,

    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core') {
    throw 'PowerShell 7 (pwsh) is required. Re-run with pwsh.exe.'
}

$WSL_USER = 'lasve046'

# ---------------------------------------------------------------------------
# WSL helpers
# ---------------------------------------------------------------------------
function Invoke-Wsl {
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$IgnoreExitCode
    )
    $output = & wsl -u $WSL_USER -- bash -lc $Command 2>&1
    $exitCode = $LASTEXITCODE
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "WSL command failed ($exitCode): $Command`n$output"
    }
    return $output
}

function Test-WslOllamaInstalled {
    & wsl -u $WSL_USER -- bash -lc 'command -v ollama >/dev/null 2>&1'
    return ($LASTEXITCODE -eq 0)
}

# ---------------------------------------------------------------------------
# Model data
# ---------------------------------------------------------------------------
function Get-ModelMatrix {
    return @(
        [PSCustomObject]@{ Model = 'qwen2.5-coder'; Dev = 'H'; Debug = 'H'; Business = 'L'; Creative = 'L'; Organize = 'M'; BestFor = 'coding, refactors, tests' },
        [PSCustomObject]@{ Model = 'deepseek-r1:8b'; Dev = 'H'; Debug = 'H'; Business = 'M'; Creative = 'L'; Organize = 'H'; BestFor = 'root-cause analysis and troubleshooting' },
        [PSCustomObject]@{ Model = 'phi4-mini'; Dev = 'M'; Debug = 'M'; Business = 'H'; Creative = 'M'; Organize = 'H'; BestFor = 'fast notes, planning, summaries' },
        [PSCustomObject]@{ Model = 'phi4'; Dev = 'M'; Debug = 'M'; Business = 'H'; Creative = 'M'; Organize = 'H'; BestFor = 'business writing and structured outputs' },
        [PSCustomObject]@{ Model = 'llama3.2'; Dev = 'M'; Debug = 'M'; Business = 'M'; Creative = 'M'; Organize = 'M'; BestFor = 'general everyday assistant work' },
        [PSCustomObject]@{ Model = 'llama3.3'; Dev = 'M'; Debug = 'M'; Business = 'H'; Creative = 'H'; Organize = 'M'; BestFor = 'long-form drafting and creative writing' },
        [PSCustomObject]@{ Model = 'mistral'; Dev = 'M'; Debug = 'M'; Business = 'M'; Creative = 'H'; Organize = 'M'; BestFor = 'rewriting and idea generation' }
    )
}

function Get-ModelPacks {
    return [ordered]@{
        Starter          = @('qwen2.5-coder', 'deepseek-r1:8b', 'phi4-mini', 'llama3.2')
        DeveloperDebug   = @('qwen2.5-coder', 'deepseek-r1:8b', 'llama3.2')
        BusinessCreative = @('phi4', 'llama3.3', 'mistral')
        All              = @('qwen2.5-coder', 'deepseek-r1:8b', 'phi4-mini', 'phi4', 'llama3.2', 'llama3.3', 'mistral')
    }
}

function Show-ModelMatrix {
    Write-Host ''
    Write-Host 'Model Fit Matrix (H=High, M=Medium, L=Low)' -ForegroundColor Yellow
    Write-Host ''

    (Get-ModelMatrix |
        Select-Object Model, Dev, Debug, Business, Creative, Organize, BestFor |
        Format-Table -AutoSize |
        Out-String -Width 220) -split "`r?`n" |
        ForEach-Object {
            if ($_.Trim().Length -gt 0) {
                Write-Host $_
            }
        }

    Write-Host ''
    Write-Host 'Pack Names:' -ForegroundColor Yellow
    Write-Host '  Starter           -> balanced first install'
    Write-Host '  DeveloperDebug    -> coding + debugging focus'
    Write-Host '  BusinessCreative  -> docs, business writing, ideation'
    Write-Host '  All               -> complete recommended set'
}

# ---------------------------------------------------------------------------
# Pull
# ---------------------------------------------------------------------------
function Pull-Models {
    param([string[]]$Models)

    if (-not (Test-WslOllamaInstalled)) {
        throw "Ollama is not installed in WSL for user '$WSL_USER'. Install it first."
    }

    $ok = @()
    $fail = @()

    foreach ($m in $Models) {
        if ([string]::IsNullOrWhiteSpace($m)) { continue }
        Write-Host "[->] Pulling $m via WSL ollama ..." -ForegroundColor Cyan
        try {
            Invoke-Wsl -Command "ollama pull '$m'" | ForEach-Object { Write-Host "  $_" }
            $ok += $m
        } catch {
            $fail += $m
            Write-Host "[!!] Failed to pull $m : $_" -ForegroundColor Red
        }
        Write-Host ''
    }

    if ($ok.Count -gt 0) {
        Write-Host "Pulled OK ($($ok.Count)): $($ok -join ', ')" -ForegroundColor Green
    }
    if ($fail.Count -gt 0) {
        Write-Host "Failed ($($fail.Count)): $($fail -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Show-ModelMatrix

if ($ListOnly) {
    exit 0
}

$packs = Get-ModelPacks
if ($CustomModels -and $CustomModels.Count -gt 0) {
    $targets = $CustomModels
    Write-Host 'Using custom model list.' -ForegroundColor Yellow
} else {
    $targets = $packs[$Pack]
    if (-not $targets) {
        throw "Unknown pack '$Pack'."
    }
    Write-Host "Using pack: $Pack" -ForegroundColor Yellow
}

Write-Host "Pulling via: wsl -u $WSL_USER -- ollama" -ForegroundColor DarkGray
Write-Host ''

Pull-Models -Models $targets
