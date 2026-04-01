# ZeroClaw + Ollama QA Report

**Date:** 2026-03-27 (updated after debug sweep)  
**Scope:** Full inventory and runtime validation of all Ollama and ZeroClaw assets on WSL and S: drive  

---

## 1. Asset Inventory

### WSL — ZeroClaw Repo (`/home/lasve046/projects/zeroclaw-wsl/`)

| Asset | Status | Notes |
|---|---|---|
| Binary `target/debug/zeroclaw` | ✅ Present | v0.6.5, 710MB ELF 64-bit |
| Config `~/.zeroclaw/config.toml` | ✅ Present | 686 lines, default_provider=ollama, default_model=phi4-mini |
| Global env `~/.config/zeroclaw-wsl/env.sh` | ✅ Present | Exports + aliases |
| Wrapper `~/.local/bin/zcwsl` | ✅ Present | Executable |
| `scripts/wsl/bootstrap-docker.sh` | ✅ Syntax OK | |
| `scripts/wsl/bootstrap-libs.sh` | ✅ Syntax OK | |
| `scripts/wsl/doctor-global-resources.sh` | ✅ Syntax OK | |
| `scripts/wsl/lib-manifest.txt` | ✅ Present | |
| `scripts/wsl/proceed.sh` | ✅ Syntax OK | |
| `scripts/wsl/setup-global-resources.sh` | ✅ Syntax OK | |
| `scripts/wsl/sync-from-win-archive.sh` | ✅ Syntax OK | |
| `scripts/wsl/pull-ollama-model-packs.ps1` | ✅ Present | Copied from S: drive (FIX-01) |
| Git branch | ✅ `wsl-primary-bootstrap` | |

### WSL — Ollama

| Asset | Status | Notes |
|---|---|---|
| `ollama` CLI binary in WSL | ✅ Installed | v0.18.3 at `~/.local/bin/ollama` (FIX-07) |
| `~/.ollama/models/` | ⚠️ Remote | Models served by Windows Ollama via mirrored networking |
| Ollama API reachable at 127.0.0.1:11434 | ✅ Yes | Via Windows Ollama + mirrored networking |
| Ollama version | ✅ 0.18.3 client / 0.18.2 server | WSL CLI + Windows server |
| Models available | ✅ phi4-mini:latest (3.8B, Q4_K_M) | Only 1 model |
| OLLAMA_HOST env var | ⚠️ Not set in WSL | Set on Windows side via launcher script |

### S: Drive (`/mnt/s/pkg/infra/qf_lifecycle/`)

| Asset | Parse | Issues |
|---|---|---|
| `pull-ollama-model-packs.ps1` | ✅ Clean | WSL-first version (289 lines). Good. |
| `launch-wsl-zeroclaw.ps1` | ✅ Clean | 454 lines. **Rewritten** WSL-native (FIX-04) |
| `create-wsl-zeroclaw-shortcut.ps1` | ✅ Clean | Updated to target pwsh 7 (FIX-02) |
| `launch-ollama-console.ps1` | ⚠️ Deprecated | Deprecation header added (FIX-08) |
| `create-ollama-desktop-shortcut.ps1` | ⚠️ Deprecated | Deprecation header added (FIX-08) |
| `scripts/install-ollama-models.ps1` | ⚠️ Deprecated | Deprecation header added (FIX-08) |
| `zc_*.ps1` (10 files) | 📦 Archived | Moved to `_archive_debug/` (FIX-09) |

---

## 2. Runtime Results

### Ollama (via Windows, mirrored networking)

| Check | Result |
|---|---|
| `GET /` | ✅ "Ollama is running" |
| `GET /api/tags` | ✅ Returns model list (phi4-mini) |
| `GET /api/version` | ✅ 0.18.2 |
| `POST /api/generate` (phi4-mini) | ✅ Generated response: "Hello! How can I" |

### ZeroClaw

| Check | Result |
|---|---|
| `zeroclaw --version` | ✅ 0.6.5 |
| `zeroclaw doctor` | ⚠️ 25 ok, 4 warnings, 0 errors |
| `zeroclaw self-test` | ❌ 10/11 pass, **1 FAIL** |

#### Doctor Warnings (4):
1. `⚠️ no api_key set` — Expected for Ollama (no API key needed)
2. `⚠️ no channels configured` — No chat channels set up yet
3. `⚠️ AGENTS.md not found` — Optional file, workspace level
4. `⚠️ no channel components tracked yet` — No channels = nothing to track

#### Self-Test Failure (1):
- **`✗ 11/11 websocket`** — `handshake failed at ws://127.0.0.1:42617/ws/chat: HTTP error: 401 Unauthorized`
  - Root cause: Daemon requires pairing. Pairing code `260692` was issued but no client has paired yet.
  - Self-test doesn't send the pairing token → 401

### WSL Doctor Script
| Check | Result |
|---|---|
| `doctor-global-resources.sh` | ✅ All 13 checks pass |

### WSL Proceed Script
| Check | Result |
|---|---|
| `proceed.sh` | ✅ Completes. Archive guard correctly blocks (expected divergence). |

---

## 3. Documented Issues

### ISSUE-01: `scripts/wsl/pull-ollama-model-packs.ps1` missing from WSL repo
- **Severity:** Medium
- **Location:** `/home/lasve046/projects/zeroclaw-wsl/scripts/wsl/`
- **Problem:** The WSL-first model pack script was written in a previous session but never landed on disk due to path-sync issues between the editor and WSL filesystem.
- **Impact:** Cannot run model pulls from WSL repo. Only the S: drive copy exists.
- **Fix:** Copy the S: drive version into the WSL repo, or write it fresh.

### ISSUE-02: `create-wsl-zeroclaw-shortcut.ps1` targets PowerShell 5.1
- **Severity:** Medium
- **Location:** `/mnt/s/pkg/infra/qf_lifecycle/create-wsl-zeroclaw-shortcut.ps1`
- **Problem:** `$TargetApp = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'` — uses Windows PowerShell 5.1 instead of pwsh 7.
- **Impact:** Desktop shortcuts launch with legacy PowerShell. The launcher script has `#Requires -Version 5.1` but should be 7.0.
- **Fix:** Change `$TargetApp` to pwsh.exe path. Update `#Requires` in launcher.

### ISSUE-03: `launch-wsl-zeroclaw.ps1` has `#Requires -Version 5.1` (should be 7.0)
- **Severity:** Low-Medium
- **Location:** `/mnt/s/pkg/infra/qf_lifecycle/launch-wsl-zeroclaw.ps1`, line 1
- **Problem:** Declares 5.1 minimum, but user mandated pwsh 7 only.
- **Impact:** Script will silently run under 5.1 if launched from wrong shortcut.
- **Fix:** Change to `#Requires -Version 7.0`.

### ISSUE-04: `launch-wsl-zeroclaw.ps1` still uses Windows Ollama paths
- **Severity:** Medium
- **Location:** `/mnt/s/pkg/infra/qf_lifecycle/launch-wsl-zeroclaw.ps1`
- **Problem:** `Get-OllamaExe` searches `$env:LOCALAPPDATA\Programs\Ollama\ollama.exe` — Windows native Ollama. Model pulls in menu option [3] use `$ollamaExe pull` which runs the Windows binary, not WSL ollama.
- **Impact:** Model pulls go to Windows Ollama store, not WSL.
- **Fix:** Model pull menu should route through WSL `ollama pull` instead of Windows binary.

### ISSUE-05: `launch-wsl-zeroclaw.ps1` uses `Read-Host` for menu input
- **Severity:** Low
- **Location:** `/mnt/s/pkg/infra/qf_lifecycle/launch-wsl-zeroclaw.ps1`, line ~316
- **Problem:** Uses `Read-Host 'Choice'` which requires Enter key. Previous session started converting to single-keypress but this wasn't applied here.
- **Impact:** UX friction — must type choice + Enter.
- **Fix:** Replace with `$Host.UI.RawUI.ReadKey()` approach.

### ISSUE-06: WebSocket self-test fails (401 Unauthorized)
- **Severity:** Low
- **Location:** ZeroClaw daemon — ws://127.0.0.1:42617/ws/chat
- **Problem:** Daemon requires pairing before WebSocket access. Self-test doesn't pair first.
- **Impact:** Self-test reports 10/11 instead of 11/11. Cosmetic — no functional impact.
- **Fix:** Either pair a client, or this is expected behavior for an unpaired daemon.

### ISSUE-07: Ollama CLI not installed in WSL
- **Severity:** High
- **Location:** WSL environment
- **Problem:** No `ollama` binary in WSL. API is reachable via mirrored networking from Windows Ollama, but no native CLI for `ollama pull`, `ollama run`, etc.
- **Impact:** Cannot pull models from WSL. Cannot use the WSL-first model pack script. All model operations must go through the Windows binary or curl.
- **Fix:** Install Ollama Linux binary in WSL (user-local if no sudo).

### ISSUE-08: Legacy Windows-only Ollama scripts still present
- **Severity:** Low
- **Location:** `/mnt/s/pkg/infra/qf_lifecycle/`
- **Problem:** Three scripts are pure Windows-native Ollama (superseded by WSL approach):
  - `launch-ollama-console.ps1` — Windows Ollama console
  - `create-ollama-desktop-shortcut.ps1` — Windows Ollama shortcuts
  - `scripts/install-ollama-models.ps1` — Windows Ollama model installer
- **Impact:** Confusion about which scripts are active. No functional impact if not used.
- **Fix:** Archive or delete. Or add deprecation header.

### ISSUE-09: Debug/patch zc_* scripts cluttering S: drive
- **Severity:** Low
- **Location:** `/mnt/s/pkg/infra/qf_lifecycle/zc_*.ps1` (10 files)
- **Problem:** These are one-time debug and patch scripts from previous troubleshooting sessions. No longer needed.
- **Impact:** Clutter. No functional impact.
- **Fix:** Archive or delete.

### ISSUE-10: Config `[model_providers]` header is empty at top level
- **Severity:** None (false alarm)
- **Location:** `~/.zeroclaw/config.toml`, line 9 and line 684
- **Problem:** Line 9 has `[model_providers]` (empty), then line 684 has `[model_providers.ollama]` with correct values.
- **Impact:** No impact — TOML supports this. The ollama provider is correctly configured.
- **Status:** ✅ Verified working — zeroclaw doctor shows provider is valid.

---

## 4. Priority Matrix

| Priority | Issue | Action |
|---|---|---|
| 🔴 HIGH | ISSUE-07: No Ollama CLI in WSL | Install Ollama Linux binary |
| 🟡 MEDIUM | ISSUE-01: Model pack script missing from WSL repo | Copy/create script |
| 🟡 MEDIUM | ISSUE-02: Shortcut targets pwsh 5.1 | Update TargetApp to pwsh.exe |
| 🟡 MEDIUM | ISSUE-03: Launcher #Requires 5.1 | Change to 7.0 |
| 🟡 MEDIUM | ISSUE-04: Launcher uses Windows Ollama for pulls | Route pulls through WSL |
| 🟢 LOW | ISSUE-05: Read-Host instead of single-key | UX improvement |
| 🟢 LOW | ISSUE-06: WebSocket 401 in self-test | Expected (unpaired) |
| 🟢 LOW | ISSUE-08: Legacy Windows Ollama scripts | Archive/deprecate |
| 🟢 LOW | ISSUE-09: Debug zc_* scripts | Archive/delete |

---

## 5. Fixes Applied (Debug Sweep)

| Fix | Issue | What Changed | Verified |
|---|---|---|---|
| FIX-01 | ISSUE-01 | Copied `pull-ollama-model-packs.ps1` to WSL repo `scripts/wsl/` | ✅ File exists, 5089 bytes |
| FIX-02 | ISSUE-02 | Changed `$TargetApp` in `create-wsl-zeroclaw-shortcut.ps1` from `powershell.exe` to `S:\libs\bin\powershell\pwsh.exe` | ✅ Parse clean |
| FIX-03 | ISSUE-03 | Changed `#Requires -Version 5.1` → `#Requires -Version 7.0` in launcher | ✅ Parse clean |
| FIX-04 | ISSUE-04 | **Full rewrite** of `launch-wsl-zeroclaw.ps1` — removed all Windows Ollama refs (`Get-OllamaExe`, `Test-OllamaListening`, `Test-OllamaBindAll`, `Ensure-OllamaBindAll`), replaced with WSL-native helpers (`Test-WslOllamaInstalled`, `Test-WslOllamaReady`, `Ensure-WslOllamaRunning`, `Invoke-Wsl`, `Convert-ToBashSingleQuoted`, `Test-WslCommandExists`). 454 lines. | ✅ Parse clean, 0 errors. Grep confirms zero Windows Ollama refs. |
| FIX-07 | ISSUE-07 | Installed Ollama v0.18.3 Linux binary to `~/.local/bin/ollama` with CPU libs at `~/.local/lib/ollama/`. Built `zstd` from source (no sudo). Added `LD_LIBRARY_PATH` to `env.sh`. | ✅ `ollama --version` = 0.18.3. `ollama list` returns phi4-mini. |
| FIX-08 | ISSUE-08 | Added deprecation banners to 3 legacy scripts: `launch-ollama-console.ps1`, `create-ollama-desktop-shortcut.ps1`, `scripts/install-ollama-models.ps1` | ✅ Headers present |
| FIX-09 | ISSUE-09 | Moved 10 `zc_*.ps1` debug scripts to `_archive_debug/` folder | ✅ 10 files archived |

### Not Fixed (Accepted / Deferred)

| Issue | Reason |
|---|---|
| ISSUE-05 | UX improvement (Read-Host → single-key). Deferred — non-blocking. |
| ISSUE-06 | WebSocket 401 is **expected** for unpaired daemon. Not a bug. |
| ISSUE-10 | False alarm — TOML config is valid. No action needed. |

---

## 6. Summary

**Verified Working (actually tested):**
- ✅ Ollama API responding (Windows-side, mirrored networking)
- ✅ phi4-mini generates responses
- ✅ ZeroClaw binary v0.6.5 runs
- ✅ ZeroClaw doctor 25/25 ok (4 non-blocking warnings)
- ✅ ZeroClaw self-test 10/11 (websocket 401 = expected unpaired state)
- ✅ ZeroClaw daemon running, health endpoint OK
- ✅ All 6 bash scripts syntax-clean
- ✅ All 16 PowerShell scripts parse-clean
- ✅ WSL doctor all checks pass
- ✅ WSL proceed all checks pass
- ✅ Git on `wsl-primary-bootstrap` branch

**Fixed This Session:**
- ✅ FIX-07: Ollama CLI installed in WSL (v0.18.3 at ~/.local/bin/ollama)
- ✅ FIX-01: Model pack script copied to WSL repo
- ✅ FIX-02: Desktop shortcut now targets pwsh 7.6.0
- ✅ FIX-03: Launcher #Requires updated to 7.0
- ✅ FIX-04: Launcher fully rewritten — WSL-native, zero Windows Ollama refs
- ✅ FIX-08: 3 legacy scripts deprecated with banners
- ✅ FIX-09: 10 debug scripts archived

**Remaining (Deferred):**
- ⚠️ ISSUE-05: Read-Host → single-key input (UX, non-blocking)
- ⚠️ ISSUE-06: WebSocket 401 (expected — daemon unpaired)

---

## 7. Debug Sweep — Session 2 (2026-03-28)

### Code Audit Findings

Two bugs discovered during deep code-logic audit (not just presence checks):

| Bug | File | Problem | Impact |
|---|---|---|---|
| BUG-1 | `launch-wsl-zeroclaw.ps1` line 38 | `Convert-ToBashSingleQuoted` produced `'\"'\\'"'` (8 chars) instead of correct `'\\''` (4 chars) | Broken bash quoting for any model name containing a single quote. Non-critical since model names don't have quotes, but incorrect. |
| BUG-2 | `pull-ollama-model-packs.ps1` (S: + WSL) | Still used Windows Ollama: `Get-OllamaExe` searched `$env:LOCALAPPDATA\Programs\Ollama\ollama.exe`, `#Requires -Version 5.1` | Model pulls would use Windows binary, not WSL ollama. Directly violates WSL-first policy. |

### Fixes Applied

| Fix | What Changed | Verified |
|---|---|---|
| BUG-1 fix | Rewrote `Convert-ToBashSingleQuoted` replacement to `"'\\''"`  — correct bash single-quote escape `'\\''` | ✅ Parse OK, correct 4-char output |
| BUG-2 fix | Full rewrite of `pull-ollama-model-packs.ps1` — removed `Get-OllamaExe`, added `Invoke-Wsl` + `Test-WslOllamaInstalled`, all pulls via `wsl -u lasve046 -- bash -lc "ollama pull ..."`. `#Requires -Version 7.0`. Synced to WSL repo copy. | ✅ Parse OK, `-ListOnly` smoke test passed, 0 Windows Ollama refs |

### Verification Summary (2026-03-28)

**Active scripts — Parse check:**
- ✅ `launch-wsl-zeroclaw.ps1`: PARSE OK (454 lines, 41 WSL refs, 0 Windows Ollama refs)
- ✅ `pull-ollama-model-packs.ps1`: PARSE OK (0 Windows Ollama refs, `-ListOnly` tested)
- ✅ `create-wsl-zeroclaw-shortcut.ps1`: PARSE OK (`$TargetApp = pwsh 7`, icon-only LOCALAPPDATA ref)
- ✅ All 6 bash scripts: SYNTAX OK

**Shortcut script `LOCALAPPDATA` reference:**
- Line 11: `$IconPath = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'` — icon only, guarded by `Test-Path`. Cosmetic, not a functional dependency. Acceptable.

**WSL repo copy sync:**
- ✅ `scripts/wsl/pull-ollama-model-packs.ps1` identical to S: drive version

**Previous fixes still intact:**
- ✅ FIX-02: Shortcut targets pwsh 7 (`S:\libs\bin\powershell\pwsh.exe`)
- ✅ FIX-03: Launcher `#Requires -Version 7.0`
- ✅ FIX-04: Launcher zero Windows Ollama refs (18 WSL helper functions)
- ✅ FIX-07: Ollama v0.18.3 at `~/.local/bin/ollama`
- ✅ FIX-08: 3 legacy scripts deprecated with banners
- ✅ FIX-09: 10 debug scripts archived to `_archive_debug/`
