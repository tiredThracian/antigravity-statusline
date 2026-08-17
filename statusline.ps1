#!/usr/bin/env pwsh
param(
    [Parameter(ValueFromPipeline)]
    [string]$inputJson
)

$ErrorActionPreference = 'SilentlyContinue'

# Global safety trap to ensure 0 exit code on any unhandled runtime engine error
trap {
    Write-Host "🟢 READY | 💡 Gemini"
    exit 0
}

try {
    # Ensure standard output encoding is UTF-8 so Unicode characters display correctly
    [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    if ([string]::IsNullOrWhiteSpace($inputJson)) {
        # Input JSON from stdin
        try {
            $inputJson = [System.Console]::In.ReadToEnd()
        } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($inputJson)) {
        $inputJson = '{}'
    }

    # Parse JSON Safely
    try {
        $data = ConvertFrom-Json $inputJson -ErrorAction SilentlyContinue
        if ($data) {
            $hp = $env:USERPROFILE
            if ([string]::IsNullOrEmpty($hp)) { $hp = $env:HOME }
            $dumpPath = Join-Path $hp ".gemini\antigravity-cli\last_payload.json"
            $inputJson | Out-File -FilePath $dumpPath -Encoding utf8 -Force -ErrorAction SilentlyContinue
        }
    } catch {
        $data = @{}
    }

    # --- ANSI Helpers (Standard 16-color palette) -------------------------------
    $R = "$([char]0x1b)[0m"         # Reset
    $B = "$([char]0x1b)[1m"         # Bold
    $D = "$([char]0x1b)[2m"         # Dim
    $I = "$([char]0x1b)[3m"         # Italic

    # Foreground accents
    $FG_BLACK = "$([char]0x1b)[30m"
    $FG_RED = "$([char]0x1b)[31m"
    $FG_GREEN = "$([char]0x1b)[32m"
    $FG_YELLOW = "$([char]0x1b)[33m"
    $FG_BLUE = "$([char]0x1b)[34m"
    $FG_MAGENTA = "$([char]0x1b)[35m"
    $FG_CYAN = "$([char]0x1b)[36m"
    $FG_WHITE = "$([char]0x1b)[37m"

    $FG_GRAY = "$([char]0x1b)[90m"
    $FG_BRIGHT_RED = "$([char]0x1b)[91m"
    $FG_BRIGHT_GREEN = "$([char]0x1b)[92m"
    $FG_BRIGHT_YELLOW = "$([char]0x1b)[93m"
    $FG_BRIGHT_BLUE = "$([char]0x1b)[94m"
    $FG_BRIGHT_MAGENTA = "$([char]0x1b)[95m"
    $FG_BRIGHT_CYAN = "$([char]0x1b)[96m"
    $FG_BRIGHT_WHITE = "$([char]0x1b)[97m"

    $NUM_COLOR = "${FG_BRIGHT_WHITE}${B}"
    $DOT = "${FG_GRAY} | ${R}"

    # --- Icons & Glyphs Configuration --------------------------------------------
    $USE_NERD_FONTS = $false
    if ($env:USE_NERD_FONTS -eq "false") {
        $USE_NERD_FONTS = $false
    }

    $ICON_WIDTH_ADJUST = 0
    if ($env:ICON_WIDTH_ADJUST) {
        if ([int]::TryParse($env:ICON_WIDTH_ADJUST, [ref]$val)) {
            $ICON_WIDTH_ADJUST = $val
        }
    }

    # Get-Char helper function to safely generate Unicode characters on any encoding/platform
    function Get-Char([long]$code) {
        if ($code -le 0xFFFF) { return [char]$code }
        return [char]::ConvertFromUtf32($code)
    }

    if ($USE_NERD_FONTS) {
        # State icons
        $ICON_READY = Get-Char 0xF192
        $ICON_THINKING = Get-Char 0xF07F7
        $ICON_WORKING = Get-Char 0xF423
        $ICON_TOOL = Get-Char 0xF425
        $ICON_UNKNOWN = Get-Char 0xF252
        
        # Component icons
        $ICON_FOLDER = Get-Char 0xEA83
        $ICON_MODEL = Get-Char 0xF400
        $ICON_BRANCH = Get-Char 0xF418
        $ICON_CONV = Get-Char 0xF036A
        $ICON_CTX = Get-Char 0xF134F
        $ICON_TOK = Get-Char 0xE26B
        $ICON_ART = Get-Char 0xF0F6
        $ICON_SUB = Get-Char 0xF167A
        $ICON_BG = Get-Char 0xF0AE
        
        # Sandbox icons
        $ICON_SB_NET = Get-Char 0xF0499
        $ICON_SB_NONET = Get-Char 0xF0D34
        $ICON_SB_OFF = Get-Char 0xF099C
    } else {
        # Fallback standard emojis/unicode
        $ICON_READY = Get-Char 0x1F7E2
        $ICON_THINKING = Get-Char 0x1F4AD
        $ICON_WORKING = Get-Char 0x2699
        $ICON_TOOL = Get-Char 0x2692
        $ICON_UNKNOWN = Get-Char 0x23F3
        
        $ICON_FOLDER = Get-Char 0x1F4C1
        $ICON_MODEL = Get-Char 0x1F4A1
        $ICON_BRANCH = Get-Char 0x2387
        $ICON_CONV = Get-Char 0x1F4AC
        $ICON_CTX = Get-Char 0x1F4CA
        $ICON_TOK = Get-Char 0x1FA99
        $ICON_ART = Get-Char 0x1F4C4
        $ICON_SUB = Get-Char 0x1F916
        $ICON_BG = Get-Char 0x1F4CB
        
        $ICON_SB_NET = Get-Char 0x1F4E6
        $ICON_SB_NONET = (Get-Char 0x1F4E6) + (Get-Char 0x1F512)
        $ICON_SB_OFF = Get-Char 0x1F6AB
    }

    # --- Dynamic Icon Regex Pattern Generation ---
    $all_icons = @(
        $ICON_READY, $ICON_THINKING, $ICON_WORKING, $ICON_TOOL, $ICON_UNKNOWN,
        $ICON_FOLDER, $ICON_MODEL, $ICON_BRANCH, $ICON_CONV, $ICON_CTX, $ICON_TOK,
        $ICON_ART, $ICON_SUB, $ICON_BG, $ICON_SB_NET, $ICON_SB_NONET, $ICON_SB_OFF
    )
    $unique_chars = @{}
    foreach ($icon in $all_icons) {
        if ($icon) {
            for ($iconIdx = 0; $iconIdx -lt $icon.Length; $iconIdx++) {
                if ([char]::IsSurrogate($icon, $iconIdx)) {
                    $pair = $icon.Substring($iconIdx, 2)
                    $unique_chars[$pair] = $true
                    $iconIdx++
                } else {
                    $unique_chars[$icon[$iconIdx].ToString()] = $true
                }
            }
        }
    }
    $char_list = @()
    foreach ($key in $unique_chars.Keys) {
        $char_list += [regex]::Escape($key)
    }
    $ICON_PATTERN = "(" + ($char_list -join "|") + ")"

    # Box Drawing & Block Constants
    $BLOCK_FULL = Get-Char 0x2588  # Full Block
    $BLOCK_DARK = Get-Char 0x2593  # Dark Shade
    $BLOCK_MED  = Get-Char 0x2592  # Medium Shade
    $BLOCK_LIGHT = Get-Char 0x2591 # Light Shade
    $BOX_SLASH = Get-Char 0x2571   # Box Diagonal Slash

    # --- Extract JSON Fields Safely ----------------------------------------------
    $STATE = if ($data.agent_state) { $data.agent_state } else { "idle" }
    $USED_PCT = if ($data.context_window -and $data.context_window.used_percentage) { [double]$data.context_window.used_percentage } else { 0 }
    $SANDBOX = if ($data.sandbox -and $data.sandbox.enabled -ne $null) { [bool]$data.sandbox.enabled } else { $false }
    $SANDBOX_NET = if ($data.sandbox -and $data.sandbox.allow_network) { [bool]$data.sandbox.allow_network } else { $false }

    # --- Sandbox State Fail-safe Handling ---
    # Workaround for unpopulated payload field in agy 1.0.6
    $homePath = $env:USERPROFILE
    if ([string]::IsNullOrEmpty($homePath)) { $homePath = $env:HOME }
    $SANDBOX_LOG = Join-Path $homePath ".gemini/antigravity-cli/cli.log"

    if (-not $SANDBOX) {
        if (Test-Path $SANDBOX_LOG -PathType Leaf) {
            try {
                $stream = [System.IO.File]::Open($SANDBOX_LOG, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $reader = [System.IO.StreamReader]::new($stream)
                $logContent = $reader.ReadToEnd()
                $reader.Dispose()
                $stream.Dispose()
                
                if ($logContent -match "enabling terminal sandbox") {
                    $SANDBOX = $true
                }
            } catch {}
        }
    }
    $ARTIFACTS = if ($data.artifact_count) { [int]$data.artifact_count } else { 0 }
    $BG_TASKS = if ($data.task_count) { [int]$data.task_count } else { 0 }
    $MODEL_ID = if ($data.model -and $data.model.id) { $data.model.id } else { "" }
    $MODEL_NAME = if ($data.model -and $data.model.display_name) { $data.model.display_name } else { "" }
    $COLS = if ($data.terminal_width) { [int]$data.terminal_width } else { 80 }
    $CWD = if ($data.cwd) { $data.cwd } else { "" }
    $CONV_ID = if ($data.conversation_id) { $data.conversation_id } else { "" }
    $INPUT_TOKENS = if ($data.context_window -and $data.context_window.total_input_tokens) { [int64]$data.context_window.total_input_tokens } else { 0 }
    $OUTPUT_TOKENS = if ($data.context_window -and $data.context_window.total_output_tokens) { [int64]$data.context_window.total_output_tokens } else { 0 }
    $TXT_LIMIT = if ($data.context_window -and $data.context_window.context_window_size) { [int64]$data.context_window.context_window_size } else { 0 }

    # Calculate actual tokens residing in active context window
    $CTX_USED = 0
    if ($TXT_LIMIT -gt 0 -and $USED_PCT -gt 0) {
        $CTX_USED = [int64][math]::Round(($USED_PCT / 100.0) * $TXT_LIMIT)
    } elseif ($data.context_window -and $data.context_window.current_usage) {
        $u = $data.context_window.current_usage
        $CTX_USED = [int64]($u.input_tokens + $u.output_tokens + $u.cache_read_input_tokens + $u.cache_creation_input_tokens)
    }

    $SUBAGENTS = 0
    if ($data.subagents) {
        if ($data.subagents -is [array]) {
            $SUBAGENTS = $data.subagents.Count
        } else {
            $SUBAGENTS = [int]$data.subagents
        }
    }

    # --- Quota properties ---
    $QUOTA_5H_FRAC = -1.0
    $QUOTA_5H_RESET = 0
    $QUOTA_WEEKLY_FRAC = -1.0
    $QUOTA_WEEKLY_RESET = 0

    if ($data.quota) {
        # 5-hour quota lookups
        $q5 = $data.quota."gemini-5h"
        if (!$q5) { $q5 = $data.quota."5h" }
        if ($q5) {
            if ($q5.remaining_fraction -ne $null) { $QUOTA_5H_FRAC = [double]$q5.remaining_fraction }
            if ($q5.reset_in_seconds -ne $null) { $QUOTA_5H_RESET = [int]$q5.reset_in_seconds }
        }
        
        # Weekly quota lookups (checks gemini-weekly, weekly, gemini-7d, 7d)
        $qWk = $data.quota."gemini-weekly"
        if (!$qWk) { $qWk = $data.quota."weekly" }
        if (!$qWk) { $qWk = $data.quota."gemini-7d" }
        if (!$qWk) { $qWk = $data.quota."7d" }
        if ($qWk) {
            if ($qWk.remaining_fraction -ne $null) { $QUOTA_WEEKLY_FRAC = [double]$qWk.remaining_fraction }
            if ($qWk.reset_in_seconds -ne $null) { $QUOTA_WEEKLY_RESET = [int]$qWk.reset_in_seconds }
        }
    }

    # Fallback: if no quota structure provided or only 5h fraction exists, check raw top-level fields
    if ($QUOTA_WEEKLY_FRAC -lt 0 -and $data.weekly_remaining_fraction -ne $null) {
        $QUOTA_WEEKLY_FRAC = [double]$data.weekly_remaining_fraction
        if ($data.weekly_reset_in_seconds -ne $null) { $QUOTA_WEEKLY_RESET = [int]$data.weekly_reset_in_seconds }
    }

    # --- VCS direct Git queries --------------------------------------------------
    $VCS_BRANCH = ""
    $VCS_DIRTY = $false
    $GIT_DIR = if (![string]::IsNullOrEmpty($CWD)) { $CWD } else { "." }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $branchObj = git -C "$GIT_DIR" rev-parse --abbrev-ref HEAD 2>$null
            if ($LastExitCode -eq 0 -and $branchObj) {
                $VCS_BRANCH = ($branchObj | Out-String).Trim()
                
                $statusObj = git -C "$GIT_DIR" status --porcelain 2>$null
                if ($statusObj) {
                    $VCS_DIRTY = $true
                }
            }
        } catch {}
    }

    # --- Measure Visible Length (Stripping ANSI & Multi-width count) -------------
    function Get-VisibleLength ($str) {
        if ([string]::IsNullOrEmpty($str)) { return 0 }
        
        $ansiPattern = "$([char]0x1b)\[[0-9;]*m"
        $clean = $str -replace $ansiPattern, ""
        
        # Base character count
        $base_len = [System.Globalization.StringInfo]::new($clean).LengthInTextElements
        
        # Emojis/wide icons take 2 terminal columns on Windows console
        $icon_count = 0
        if ($ICON_PATTERN) {
            $matches = [regex]::Matches($clean, $ICON_PATTERN)
            $icon_count = $matches.Count
        }
        
        # Default to +1 extra cell per icon if not specified
        $extra_width = if ($ICON_WIDTH_ADJUST -ne 0) { $ICON_WIDTH_ADJUST } else { 1 }
        
        return $base_len + ($icon_count * $extra_width)
    }

    # --- Path Shortening Helper --------------------------------------------------
    function Get-ShortenedPath ($path, $maxLen) {
        if ([string]::IsNullOrEmpty($path)) { return "" }
        
        $homePath = $env:USERPROFILE
        if ([string]::IsNullOrEmpty($homePath)) { $homePath = $env:HOME }
        
        $shortPath = $path
        if (![string]::IsNullOrEmpty($homePath) -and $path.StartsWith($homePath)) {
            $shortPath = "~" + $path.Substring($homePath.Length)
        }
        
        if ($maxLen -eq 0) {
            if ($shortPath -eq "~") {
                return "~"
            } else {
                return Split-Path $path -Leaf
            }
        } elseif ($shortPath.Length -gt $maxLen) {
            return "..." + (Split-Path $path -Leaf)
        } else {
            return $shortPath
        }
    }

    # --- VCS Format Helper -------------------------------------------------------
    function Format-Branch ($maxLen) {
        if ([string]::IsNullOrEmpty($VCS_BRANCH)) { return "" }
        
        $name = $VCS_BRANCH
        if ($maxLen -gt 0 -and $name.Length -gt $maxLen) {
            $name = $name.Substring(0, $maxLen) + ".."
        }
        
        if ($VCS_DIRTY) {
            return "${FG_BRIGHT_RED}${ICON_BRANCH} ${name}${FG_BRIGHT_YELLOW}*${R}"
        } else {
            return "${FG_BRIGHT_BLUE}${ICON_BRANCH} ${name}${R}"
        }
    }

    # --- Sandbox Format Helper ---------------------------------------------------
    function Format-Sandbox ($mode) {
        if ($SANDBOX) {
            $icon = $ICON_SB_NET
            if (!$SANDBOX_NET) { $icon = $ICON_SB_NONET }
            
            if ($mode -eq "wide") {
                $label = if ($SANDBOX_NET) { "ON (net)" } else { "ON (no-net)" }
                return "${FG_GREEN}${icon} ${FG_BRIGHT_GREEN}${B}${label}${R}"
            } elseif ($mode -eq "med") {
                return "${FG_GREEN}${icon} ${FG_BRIGHT_GREEN}${B}ON${R}"
            } else {
                return "${FG_GREEN}${icon}${R}"
            }
        } else {
            if ($mode -eq "wide" -or $mode -eq "med") {
                return "${FG_RED}${ICON_SB_OFF} ${FG_BRIGHT_RED}${B}OFF${R}"
            } else {
                return "${FG_RED}${ICON_SB_OFF}${R}"
            }
        }
    }

    # --- Time Formatting Helper --------------------------------------------------
    function Format-Seconds ($s) {
        if ($s -le 0) { return "0s" }
        if ($s -ge 86400) {
            $d = [math]::Floor($s / 86400)
            $h = [math]::Floor(($s % 86400) / 3600)
            return "${d}d${h}h"
        } elseif ($s -ge 3600) {
            $h = [math]::Floor($s / 3600)
            $m = [math]::Floor(($s % 3600) / 60)
            return "${h}h${m}m"
        } elseif ($s -ge 60) {
            $m = [math]::Floor($s / 60)
            return "${m}m"
        } else {
            return "${s}s"
        }
    }

    # --- Quota Format Helper -----------------------------------------------------
    function Format-Quota ($mode) {
        $parts = @()
        if ($QUOTA_5H_FRAC -ge 0) {
            $pct5h = [int][math]::Round($QUOTA_5H_FRAC * 100)
            $reset5h = Format-Seconds $QUOTA_5H_RESET
            $parts += "${FG_CYAN}5h: ${NUM_COLOR}${pct5h}%${R} (${FG_GRAY}${reset5h}${R})"
        }
        if ($QUOTA_WEEKLY_FRAC -ge 0) {
            $pctWk = [int][math]::Round($QUOTA_WEEKLY_FRAC * 100)
            $resetWk = Format-Seconds $QUOTA_WEEKLY_RESET
            $parts += "${FG_BRIGHT_CYAN}Wk: ${NUM_COLOR}${pctWk}%${R} (${FG_GRAY}${resetWk}${R})"
        }
        
        if ($parts.Count -eq 0) { return "" }
        return "${FG_CYAN}${ICON_UNKNOWN} " + ($parts -join " ")
    }

    # --- Horizontal Separators & Joins ------------------------------------------
    function Join-WithDot {
        $items = @()
        foreach ($arg in $args) {
            if (![string]::IsNullOrEmpty($arg)) { $items += $arg }
        }
        return $items -join $DOT
    }

    function Join-WithSpace {
        $items = @()
        foreach ($arg in $args) {
            if (![string]::IsNullOrEmpty($arg)) { $items += $arg }
        }
        return $items -join "  "
    }

    # --- Human Token Formatting Helper -------------------------------------------
    function Get-HumanFormat ($num) {
        if ([string]::IsNullOrEmpty($num) -or $num -eq 0) { return "0" }
        try { $n = [int64]$num } catch { return $num }
        
        if ($n -ge 1000000) {
            $main = [math]::Floor($n / 1000000)
            $frac = [math]::Floor(($n % 1000000) / 100000)
            return "${main}.${frac}M"
        } elseif ($n -ge 1000) {
            $main = [math]::Floor($n / 1000)
            $frac = [math]::Floor(($n % 1000) / 100)
            return "${main}.${frac}K"
        } else {
            return "$n"
        }
    }

    # --- Layout Component Formatting ---------------------------------------------
    $INPUT_TOK_FMT = Get-HumanFormat $INPUT_TOKENS
    $OUTPUT_TOK_FMT = Get-HumanFormat $OUTPUT_TOKENS
    $TXT_LIMIT_FMT = Get-HumanFormat $TXT_LIMIT
    $CTX_USED_FMT = Get-HumanFormat $CTX_USED

    # State badge S
    $S = ""
    switch ($STATE) {
        "idle"     { $S = "${FG_BRIGHT_GREEN}${B}${ICON_READY} READY${R}" }
        "thinking" { $S = "${FG_BRIGHT_YELLOW}${B}${ICON_THINKING} THINKING${R}" }
        "working"  { $S = "${FG_BRIGHT_CYAN}${B}${ICON_WORKING} WORKING${R}" }
        "tool_use" { $S = "${FG_BRIGHT_MAGENTA}${B}${ICON_TOOL} TOOL${R}" }
        default    { $S = "${FG_WHITE}${B}${ICON_UNKNOWN} $($STATE.ToUpper())${R}" }
    }

    # CWD
    $CWD_WIDE_VAL = Get-ShortenedPath $CWD 20
    $DIR_WIDE = if (![string]::IsNullOrEmpty($CWD_WIDE_VAL)) { "${FG_CYAN}${ICON_FOLDER} ${R}${CWD_WIDE_VAL}${R}" } else { "" }

    $CWD_MED_VAL = Get-ShortenedPath $CWD 12
    $DIR_MED = if (![string]::IsNullOrEmpty($CWD_MED_VAL)) { "${FG_CYAN}${ICON_FOLDER} ${R}${CWD_MED_VAL}${R}" } else { "" }

    $CWD_NARROW_VAL = Get-ShortenedPath $CWD 0
    $DIR_NARROW = if (![string]::IsNullOrEmpty($CWD_NARROW_VAL)) { "${FG_CYAN}${ICON_FOLDER} ${R}${CWD_NARROW_VAL}${R}" } else { "" }

    # Model name
    $MODEL_RAW = if (![string]::IsNullOrEmpty($MODEL_NAME)) { $MODEL_NAME } else { $MODEL_ID }
    $MODEL_CLEAN = ""
    if (![string]::IsNullOrEmpty($MODEL_RAW)) {
        $MODEL_CLEAN = $MODEL_RAW -replace "^Gemini ", "" -replace " \([^)]+\)", ""
    }

    $M_WIDE = if (![string]::IsNullOrEmpty($MODEL_RAW)) { "${FG_BRIGHT_MAGENTA}${I}${ICON_MODEL} ${MODEL_RAW}${R}" } else { "" }
    $M_MED = if (![string]::IsNullOrEmpty($MODEL_CLEAN)) { "${FG_BRIGHT_MAGENTA}${I}${ICON_MODEL} ${MODEL_CLEAN}${R}" } else { "" }
    $M_NARROW = if (![string]::IsNullOrEmpty($MODEL_CLEAN)) { 
        $len = [math]::Min($MODEL_CLEAN.Length, 10)
        "${FG_BRIGHT_MAGENTA}${I}${ICON_MODEL} $($MODEL_CLEAN.Substring(0, $len))${R}" 
    } else { "" }

    # VCS
    $V_WIDE = Format-Branch 12
    $V_MED = Format-Branch 8
    $V_NARROW = Format-Branch 5

    # Conversation ID
    $CONV_WIDE = if (![string]::IsNullOrEmpty($CONV_ID)) { "${FG_GRAY}${ICON_CONV} $($CONV_ID.Substring(0, [math]::Min($CONV_ID.Length, 6)))${R}" } else { "" }
    $CONV_MED = if (![string]::IsNullOrEmpty($CONV_ID)) { "${FG_GRAY}${ICON_CONV} $($CONV_ID.Substring(0, [math]::Min($CONV_ID.Length, 4)))${R}" } else { "" }
    $CONV_NARROW = ""

    # Sandbox badge
    $SB_WIDE = Format-Sandbox "wide"
    $SB_MED = Format-Sandbox "med"
    $SB_NARROW = Format-Sandbox "narrow"

    # Context & Token Info (percentages and metrics, no bars)
    $PCT_FMT = "{0:F1}" -f $USED_PCT

    $CTX_METRICS_WIDE = "${FG_YELLOW}${ICON_CTX} ${NUM_COLOR}${PCT_FMT}%${R}"
    if ($CTX_USED -gt 0) {
        $CTX_METRICS_WIDE += " (${CTX_USED_FMT}/${TXT_LIMIT_FMT})${DOT}${FG_YELLOW}${ICON_TOK} ${R}(${INPUT_TOK_FMT} in/${OUTPUT_TOK_FMT} out)"
    }

    $CTX_METRICS_MED = "${FG_YELLOW}${ICON_CTX} ${NUM_COLOR}${PCT_FMT}%${R}"
    if ($CTX_USED -gt 0) {
        $CTX_METRICS_MED += " (${CTX_USED_FMT}/${TXT_LIMIT_FMT})"
    }

    $CTX_METRICS_NARROW = "${FG_YELLOW}${ICON_CTX} ${NUM_COLOR}$([int]$USED_PCT)%${R}"

    # Number Indicators
    $ART_WIDE = "${FG_BLUE}${ICON_ART} ${NUM_COLOR}${ARTIFACTS}${R}"
    $SUB_WIDE = "${FG_CYAN}${ICON_SUB} ${NUM_COLOR}${SUBAGENTS}${R}"
    $BG_WIDE = "${FG_MAGENTA}${ICON_BG} ${NUM_COLOR}${BG_TASKS}${R}"

    $ART_MED = "${FG_BLUE}${ICON_ART} ${NUM_COLOR}${ARTIFACTS}${R}"
    $SUB_MED = "${FG_CYAN}${ICON_SUB} ${NUM_COLOR}${SUBAGENTS}${R}"
    $BG_MED = "${FG_MAGENTA}${ICON_BG} ${NUM_COLOR}${BG_TASKS}${R}"

    $ART_NARROW = "${FG_BLUE}${ICON_ART}${NUM_COLOR}${ARTIFACTS}${R}"
    $SUB_NARROW = "${FG_CYAN}${ICON_SUB}${NUM_COLOR}${SUBAGENTS}${R}"
    $BG_NARROW = "${FG_MAGENTA}${ICON_BG}${NUM_COLOR}${BG_TASKS}${R}"

    # Quota Indicator
    $QUOTA_WIDE = Format-Quota "wide"
    $QUOTA_MED = Format-Quota "med"
    $QUOTA_NARROW = Format-Quota "narrow"

    # --- Assemble Single Row / Multi-Row Layouts ---
    # Single-row Wide Layout (Row 1 for ultra wide displays)
    $LINE1_WIDE = Join-WithDot $S $M_WIDE $CTX_METRICS_WIDE $ART_WIDE $SUB_WIDE $BG_WIDE
    $LINE2_WIDE = Join-WithDot $DIR_WIDE $V_WIDE $CONV_WIDE $SB_WIDE $QUOTA_WIDE

    $LINE1_MED = Join-WithDot $S $M_MED $CTX_METRICS_MED $ART_MED $SUB_MED $BG_MED
    $LINE2_MED = Join-WithDot $DIR_MED $V_MED $SB_MED $QUOTA_MED

    # --- Right-alignment Printer Helper ------------------------------------------
    function Print-RightAligned ($left, $right, $totalCols) {
        $left_vis = Get-VisibleLength $left
        $right_vis = Get-VisibleLength $right
        
        $pad = $totalCols - $left_vis - $right_vis
        if ($pad -ge 1) {
            $spaces = " " * $pad
            return "${left}${spaces}${right}"
        } else {
            # If total width exceeds column width, join with a separator instead of padding out into terminal line wrap
            return Join-WithDot $left $right
        }
    }

    # --- Output Compilation ------------------------------------------------------
    $MARGIN = 8

    $LEN1_WIDE = Get-VisibleLength $LINE1_WIDE
    $LEN2_WIDE = Get-VisibleLength $LINE2_WIDE

    $LEN1_MED = Get-VisibleLength $LINE1_MED
    $LEN2_MED = Get-VisibleLength $LINE2_MED

    if ($COLS -ge 135 -and $COLS -ge ($LEN1_WIDE + $LEN2_WIDE + $MARGIN)) {
        # 1. Single-row Wide Layout
        Print-RightAligned $LINE1_WIDE $LINE2_WIDE $COLS
    } elseif ($COLS -ge 100) {
        # 2. Double-Row Parallel Wide Layout
        # Row 1: State, Model | Context, Token info, Artifacts, Subagents, BG Tasks
        $R1_LEFT = Join-WithDot $S $M_WIDE
        $R1_RIGHT = Join-WithDot $CTX_METRICS_WIDE $ART_WIDE $SUB_WIDE $BG_WIDE
        # Row 2: Dir, Branch, Conv ID | Sandbox, Quota (5h + Weekly)
        $R2_LEFT = Join-WithDot $DIR_WIDE $V_WIDE $CONV_WIDE
        $R2_RIGHT = Join-WithDot $SB_WIDE $QUOTA_WIDE
        
        Print-RightAligned $R1_LEFT $R1_RIGHT $COLS
        Print-RightAligned $R2_LEFT $R2_RIGHT $COLS
    } elseif ($COLS -ge 75) {
        # 3. Double-Row Parallel Medium Layout
        $R1_LEFT = Join-WithDot $S $M_MED
        $R1_RIGHT = Join-WithDot $CTX_METRICS_MED $ART_MED $SUB_MED $BG_MED
        $R2_LEFT = Join-WithDot $DIR_MED $V_MED $CONV_MED
        $R2_RIGHT = Join-WithDot $SB_MED $QUOTA_MED
        
        Print-RightAligned $R1_LEFT $R1_RIGHT $COLS
        Print-RightAligned $R2_LEFT $R2_RIGHT $COLS
    } elseif ($COLS -ge 50) {
        # 4. Double-Row Parallel Narrow Layout
        $R1_LEFT = Join-WithDot $S $M_NARROW
        $R1_RIGHT = Join-WithDot $CTX_METRICS_NARROW (Join-WithSpace $ART_NARROW $SUB_NARROW $BG_NARROW)
        $R2_LEFT = Join-WithDot $DIR_NARROW $V_NARROW
        $R2_RIGHT = Join-WithDot $SB_NARROW $QUOTA_MED
        
        Print-RightAligned $R1_LEFT $R1_RIGHT $COLS
        Print-RightAligned $R2_LEFT $R2_RIGHT $COLS
    } else {
        # 5. Extreme Fallback
        $M_SHORT = ""
        if (![string]::IsNullOrEmpty($MODEL_CLEAN)) {
            $len = [math]::Min($MODEL_CLEAN.Length, 8)
            $M_SHORT = "${FG_GRAY} ${BOX_SLASH} ${FG_BRIGHT_MAGENTA}$($MODEL_CLEAN.Substring(0, $len))${R}"
        }
        "${S}${M_SHORT}"
        "${CTX_METRICS_NARROW}"
    }
} catch {
    # Emergency fallback print to ensure statusline never returns a non-zero exit code
    Write-Host "🟢 READY | 💡 Gemini"
}
exit 0
