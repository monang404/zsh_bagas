# Bagas AI CLI v2 --- Terminal UX Redesign (Implementation Plan)

> **Project:** `zsh_bagas-ui-fixed-2`\
> **Target:** Mengubah CLI dari *command launcher* menjadi **AI
> Workspace** bergaya Claude Code, Gemini CLI, dan Warp tanpa mengubah
> core engine Zsh.

------------------------------------------------------------------------

# Ringkasan Audit

  Area                       Skor         Catatan
  -------------------------- ------------ ----------------------------
  Information Architecture   **8.5/10**   Modul UI sudah rapi
  Visual Hierarchy           **7/10**     Terlalu banyak box
  Readability                **8/10**     Wrap sudah baik
  Mobile Termux UX           **9/10**     Responsif
  Cognitive Load             **5.5/10**   Menu terlalu panjang
  AI Agent Experience        **6/10**     Flow masih linear
  Feedback System            **7/10**     Status ada, progres kurang
  Power User Efficiency      **8/10**     Command lengkap

## Kesimpulan

-   **Skor saat ini:** **7.4/10**
-   **Target:** **9.5/10**
-   **Strategi:** Refactor layer UI (`30-ai/60-ui`) tanpa menyentuh
    dispatcher, workflow, subagent, maupun tool engine.

------------------------------------------------------------------------

# Audit Mendalam

## 1. Refactor `20-menu.zsh` (Critical)

### Masalah

Menu berisi ±27 pilihan sehingga:

-   scrolling panjang
-   fitur utama tenggelam
-   decision fatigue tinggi

### Struktur Saat Ini

``` text
Chat cepat
Chat panjang
Sesi nyambung
AI Agent
Generate kode
Edit file
Scan project
...
Statistik token
Workspace tmux
Dependency
```

### Target

``` text
AI Workspace

Chat
Quick • Session • Long

Code
Generate • Edit • Fix • Review

Project
Scan • Index • Build

Tools
Clipboard • Shell • Stats
```

### Implementasi

**File:** `30-ai/60-ui/20-menu.zsh`

Checklist:

-   [ ] Ubah menjadi launcher 4 kategori.
-   [ ] Semua command lama tetap lewat dispatcher.
-   [ ] Tambahkan shortcut `/chat`, `/code`, `/project`, `/tools`.

------------------------------------------------------------------------

## 2. AI Agent Dashboard

### Masalah

Output masih berupa step linear.

``` text
Step 1
Tool: rg
Reasoning...
Step 2
```

### Target

``` text
AI Agent
Project: zsh_bagas
RUNNING

Files      43
Tools       5
Runtime  01:23

Current Action
Tool: rg

Searching authentication functions...

✓ Found login handler
✓ Found JWT middleware
● Analyzing token validation

Next Action
Open auth/service.ts
```

### Modul Baru

    30-ai/60-ui/screens/agent.zsh
    30-ai/60-ui/components/progress.zsh
    30-ai/60-ui/components/timeline.zsh

------------------------------------------------------------------------

## 3. Refactor `05-ui_box.zsh`

### Masalah

Nested box memenuhi layar HP.

### Aturan Baru

  Level     Style
  --------- ---------
  Hero      Box
  Section   Divider
  Item      Indent

### Sebelum

``` text
┌──────────┐
│ Box      │
│ ┌──────┐ │
│ │ Box  │ │
│ └──────┘ │
└──────────┘
```

### Sesudah

``` text
┌──────────────────────────┐
│ AI Agent                 │
├──────────────────────────┤
│ Tool: rg                 │
│ Searching project...     │
└──────────────────────────┘
```

Checklist:

-   [ ] Maksimal satu hero box.
-   [ ] Hindari box di dalam box.

------------------------------------------------------------------------

## 4. Command Palette

### Masalah

Belum ada launcher modern.

### Target UX

``` text
Search command...

Chat
Quick conversation

Generate Code
Create files

Fix Project
Auto repair

↑↓ Navigate
Enter Select
Esc Exit
```

### Implementasi

**Dependency:** `gum filter`

**File baru**

    30-ai/60-ui/components/palette.zsh

API:

``` zsh
ui_palette
```

------------------------------------------------------------------------

# UX yang Hilang

## Session Header

Harus selalu tampil.

``` text
main
~/project/api
GPT-5.6

branch: main
dirty
3 files changed
```

### Data Source

-   Git
-   Session manager
-   Model config

File:

    components/header.zsh

------------------------------------------------------------------------

## Approval UX

### Saat Ini

``` text
Approve? y/n
```

### Target

``` text
Command requires approval

rm -rf build/

[Approve]
[Deny]
```

Implementasi:

-   `35-update_confirm.zsh`
-   `components/approval.zsh`

------------------------------------------------------------------------

# Information Hierarchy Baru

## Flow Baru

``` text
AI Workspace

Prompt

↓

Plan

↓

Tool Execution

↓

Result
```

### Dashboard

``` text
Current Task

Step 3/7

Editing auth.ts

✓ Scan project
✓ Locate auth module
● Editing auth.ts
○ Run tests
```

------------------------------------------------------------------------

# Mockup Final Design

## Home Screen

``` text
┌──────────────────────────────────┐
│ Bagas AI CLI                     │
│ GPT-5.6 • Termux          READY  │
├──────────────────────────────────┤
│ > Fix authentication bug         │
├──────────────────────────────────┤
│ Chat      Code                   │
│ Project   Tools                  │
├──────────────────────────────────┤
│ Recent Session: auth-api         │
│ Workspace: ~/project/backend     │
└──────────────────────────────────┘
```

------------------------------------------------------------------------

## Agent Running

``` text
┌──────────────────────────────────┐
│ AI Agent                 RUNNING │
│ Scanning project                 │
├──────────────────────────────────┤
│ Progress 4/7                     │
│ ███████████░░░░                  │
├──────────────────────────────────┤
│ ✓ Scan project                   │
│ ✓ Found auth module              │
│ ✓ Opened service.ts              │
│ ● Editing code                   │
│ ○ Run tests                      │
│ ○ Generate report                │
├──────────────────────────────────┤
│ Current command                  │
│ rg "auth"                        │
└──────────────────────────────────┘
```

------------------------------------------------------------------------

## Final Report

``` text
┌──────────────────────────────────┐
│ Task Completed          SUCCESS  │
├──────────────────────────────────┤
│ Steps    6                       │
│ Files    3                       │
│ Time    42s                      │
├──────────────────────────────────┤
│ ✓ JWT validation fixed           │
│ ✓ Tests passed                   │
│ ✓ Commit ready                   │
├──────────────────────────────────┤
│ Next Action                      │
│ Run integration tests            │
└──────────────────────────────────┘
```

------------------------------------------------------------------------

# Design System Terminal

## Color Token

  Token        Nilai
  ------------ -----------
  Background   `#0D1117`
  Surface      `#161B22`
  Border       `#30363D`
  Primary      `#2F81F7`
  Success      `#3FB950`
  Warning      `#D29922`
  Error        `#F85149`
  Text         `#E6EDF3`
  Muted        `#8B949E`

## Rules

-   satu hero box per layar
-   status memakai ikon
-   progress selalu terlihat
-   approval berbentuk card
-   command palette menjadi entry point
-   session header selalu muncul

------------------------------------------------------------------------

# Roadmap Implementasi

## Phase 1 --- Foundation

**File**

-   `02-ui_colors.zsh`
-   `05-ui_box.zsh`
-   `components/header.zsh`
-   `components/cards.zsh`

Checklist:

-   [ ] Theme konsisten
-   [ ] Hero box
-   [ ] Typography helper

------------------------------------------------------------------------

## Phase 2 --- Navigation

**Target**

-   `20-menu.zsh`
-   `40-dispatcher.zsh`
-   `components/palette.zsh`

Checklist:

-   [ ] Command Palette
-   [ ] Quick Actions
-   [ ] Router

------------------------------------------------------------------------

## Phase 3 --- Agent Workspace

Integrasi:

-   `55-subagent`
-   `20-session_mgmt.zsh`
-   `05-tools`

Checklist:

-   [ ] Timeline
-   [ ] Current Action
-   [ ] Progress
-   [ ] ETA

------------------------------------------------------------------------

## Phase 4 --- Approval UX

File:

-   `35-update_confirm.zsh`

Checklist:

-   [ ] Approval card
-   [ ] Better confirmation

------------------------------------------------------------------------

## Phase 5 --- Final Report

Integrasi:

-   `25-project_report.zsh`
-   `30-aisummarize.zsh`

Checklist:

-   [ ] Files changed
-   [ ] Runtime
-   [ ] Tool summary
-   [ ] Next action

------------------------------------------------------------------------

# ROI Prioritas

  Prioritas                Dampak
  ------------------------ ---------------
  Refactor `20-menu.zsh`   Sangat tinggi
  Sticky Session Header    Tinggi
  Agent Dashboard          Sangat tinggi
  Kurangi nested box       Tinggi
  Progress + ETA           Tinggi
  Quick Actions            Tinggi

------------------------------------------------------------------------

# Definition of Done

## Foundation

-   [ ] Theme selesai
-   [ ] Header selesai
-   [ ] Progress selesai

## Navigation

-   [ ] Command Palette
-   [ ] Quick Actions
-   [ ] Router

## Agent

-   [ ] Dashboard
-   [ ] Timeline
-   [ ] Current Action

## Report

-   [ ] Summary
-   [ ] Stats
-   [ ] Next action

## Compatibility

-   [ ] Termux (80 kolom)
-   [ ] Desktop (120 kolom)
-   [ ] Narrow mode
-   [ ] Startup tetap ringan
