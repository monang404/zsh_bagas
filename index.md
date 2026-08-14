# Bagas AI CLI v2 --- Terminal UX Redesign Implementation Plan

**Project:** zsh_bagas-ui-fixed-2\
**Version:** 2.0\
**Status:** Draft (Implementation Ready)\
**Target Platform:** Termux, Linux, macOS (Zsh)\
**Framework:** Zsh + Gum + ANSI

------------------------------------------------------------------------

# 1. Executive Summary

Tujuan redesign adalah mengubah CLI dari pola **menu launcher
tradisional** menjadi **AI Agent Workspace** yang:

-   lebih cepat digunakan
-   mengurangi cognitive load
-   mobile-first untuk Termux
-   tetap ringan (pure Zsh)
-   kompatibel dengan modul yang sudah ada

Target UX setara dengan Claude Code, Gemini CLI, OpenCode, dan Warp
Terminal.

------------------------------------------------------------------------

# 2. Design Principles

1.  Prompt-first
2.  Context-aware
3.  Progressive disclosure
4.  Minimal visual noise
5.  Keyboard-first
6.  Mobile-first
7.  Stateless UI, Stateful Session

------------------------------------------------------------------------

# 3. Current Architecture Audit

## Existing Strengths

-   Modular UI
-   Dispatcher terpisah
-   Logger
-   Completion
-   Diagnostics
-   Gum integration
-   Adaptive terminal width

## Main Problems

  Problem                  Impact
  ------------------------ ----------
  Menu terlalu panjang     High
  Box bertumpuk            High
  Agent output linear      High
  Approval kurang jelas    Medium
  Session tidak terlihat   High
  Tidak ada launcher       Critical

------------------------------------------------------------------------

# 4. Target Information Architecture

## Current

``` text
Main Menu
├── Chat
├── Long Chat
├── Session
├── AI Agent
├── Generate
├── Edit
├── Scan
├── Stats
├── Tools
└── ...
```

## Target

``` text
AI Workspace
├── Chat
├── Code
├── Project
└── Tools
```

Semua fitur lain menjadi submenu.

------------------------------------------------------------------------

# 5. Design System

## Colors

  Token        Value
  ------------ ---------
  Background   #0D1117
  Surface      #161B22
  Border       #30363D
  Primary      #2F81F7
  Success      #3FB950
  Warning      #D29922
  Danger       #F85149
  Text         #E6EDF3
  Muted        #8B949E

## Typography

Terminal native.

Hierarchy:

-   H1
-   H2
-   body
-   muted

## Spacing

  Token   Value
  ------- -------
  XS      1
  SM      2
  MD      4
  LG      6

**Rule:** Jangan gunakan nested box lebih dari 1 level.

------------------------------------------------------------------------

# 6. UI Components

  Component         Status
  ----------------- ----------
  Header            New
  Status Badge      Existing
  Progress Bar      New
  Command Palette   New
  Timeline          New
  Approval Card     New
  Summary Card      New
  Stats Card        New

------------------------------------------------------------------------

# 7. Screen Redesign

## Screen 1 --- Home Workspace

**Goal:** Menggantikan menu 27 item.

**Layout:**

-   Header
-   Prompt Input
-   Quick Actions
-   Recent Sessions
-   Workspace Info

**Module:** `30-ai/60-ui/ui_home.zsh`

------------------------------------------------------------------------

## Screen 2 --- Command Palette

**Shortcut:** `Ctrl+P` atau `/`

Menggunakan `gum filter`.

Flow:

1.  Search
2.  Filter realtime
3.  Enter
4.  Execute

Contoh `commands.json`:

``` json
[
  {"name":"Chat","cmd":"chat"},
  {"name":"Generate Code","cmd":"code"},
  {"name":"Fix Project","cmd":"fix"},
  {"name":"Scan Project","cmd":"scan"}
]
```

------------------------------------------------------------------------

## Screen 3 --- Agent Workspace

Layout:

-   Session Header
-   Current Action
-   Progress
-   Timeline
-   Tool Output
-   Next Action

Module: `ui_agent_dashboard.zsh`

------------------------------------------------------------------------

## Screen 4 --- Approval

Current:

> Approve? y/n

Target:

-   Card
-   Command
-   Buttons

Module: `ui_approval.zsh`

------------------------------------------------------------------------

## Screen 5 --- Final Report

Harus berisi:

-   Files changed
-   Runtime
-   Tools used
-   Next action

------------------------------------------------------------------------

# 8. Session Header

Selalu tampil:

-   Project
-   Branch
-   Model
-   Mode
-   Token
-   Runtime

Data source:

-   Git
-   Session manager
-   Model config

Module: `ui_header.zsh`

------------------------------------------------------------------------

# 9. Agent Timeline

Current:

``` text
Step 1
Step 2
Step 3
```

Target:

``` text
✔ Done
✔ Done
● Running
○ Pending
```

  State     Icon
  --------- ------
  Done      ✔
  Running   ●
  Pending   ○
  Error     ✖

Module: `ui_timeline.zsh`

------------------------------------------------------------------------

# 10. Progress System

Format:

-   Current step
-   Total step
-   ETA
-   Progress bar

API:

``` zsh
ui_progress current total message
```

Contoh:

``` zsh
ui_progress 3 7 "Scanning project"
```

------------------------------------------------------------------------

# 11. Quick Actions

  Shortcut   Action
  ---------- ----------
  `/chat`    Chat
  `/code`    Generate
  `/fix`     Auto Fix
  `/scan`    Scan
  `/tools`   Tools

Module: `ui_router.zsh`

------------------------------------------------------------------------

# 12. Box Refactor

Current:

``` text
Box
└── Box
    └── Box
```

Target:

``` text
Hero Box
──────────
Indented content
```

Rule:

-   Satu hero box.
-   Maksimal satu child box.

------------------------------------------------------------------------

# 13. Interaction Flow

## Chat

Open → Prompt → Response → Continue

## Code

Prompt → Plan → Approval → Execute → Report

## Project

Scan → Analyze → Suggest → Execute

------------------------------------------------------------------------

# 14. File Structure

Target:

``` text
30-ai/
└── 60-ui/
    ├── components/
    │   ├── header.zsh
    │   ├── progress.zsh
    │   ├── timeline.zsh
    │   ├── approval.zsh
    │   └── cards.zsh
    ├── screens/
    │   ├── home.zsh
    │   ├── agent.zsh
    │   ├── report.zsh
    │   └── palette.zsh
    ├── router.zsh
    └── theme.zsh
```

------------------------------------------------------------------------

# 15. Implementation Roadmap

  Phase   Fokus                     Durasi
  ------- ------------------------- ----------
  1       Theme, Header, Progress   1 hari
  2       Command Palette, Router   1 hari
  3       Agent Dashboard           2 hari
  4       Approval UX               0.5 hari
  5       Report                    0.5 hari

------------------------------------------------------------------------

# 16. Technical Tasks

## Theme Engine

File: `theme.zsh`

``` zsh
ui_color token
```

## Header

File: `header.zsh`

``` zsh
ui_header
```

## Progress

File: `progress.zsh`

``` zsh
ui_progress current total message
```

## Timeline

File: `timeline.zsh`

``` zsh
ui_timeline steps current
```

## Command Palette

File: `palette.zsh`

``` zsh
ui_palette
```

Dependency: `gum filter`

## Approval

File: `approval.zsh`

``` zsh
ui_approve command
```

## Report

File: `report.zsh`

``` zsh
ui_report
```

------------------------------------------------------------------------

# 17. Migration Strategy

Tidak mengubah:

-   dispatcher
-   logger
-   completion
-   AI engine

Perubahan hanya terjadi pada layer presentasi.

``` text
Old:
Dispatcher → Menu → Output

New:
Dispatcher → Router → Workspace → Components → Output
```

------------------------------------------------------------------------

# 18. Success Metrics

## UX Metrics

  Metric               Current     Target
  -------------------- ----------- ------------
  Menu choice          27          4
  Scroll awal          \~3 layar   1 layar
  Nested box           banyak      maksimal 1
  Approval clarity     rendah      tinggi
  Session visibility   tidak ada   selalu ada

## Performance

-   Startup di bawah 300ms.
-   Tidak ada dependency baru selain Gum.
-   Tetap kompatibel Termux.

------------------------------------------------------------------------

# 19. Future Enhancements

## v2.1

-   Floating command history
-   Token counter live
-   Diff preview
-   Split output

## v2.2

-   Multi-agent
-   Background tasks
-   Notification system

## v3

-   TUI penuh
-   Mouse support
-   Sidebar
-   Plugin marketplace

------------------------------------------------------------------------

# 20. Definition of Done

## Foundation

-   [ ] Theme selesai
-   [ ] Header selesai
-   [ ] Progress selesai

## Navigation

-   [ ] Command palette
-   [ ] Quick actions
-   [ ] Router

## Agent

-   [ ] Dashboard
-   [ ] Timeline
-   [ ] Tool panel

## Approval

-   [ ] Approval card

## Report

-   [ ] Summary
-   [ ] Stats
-   [ ] Next action

## Quality

-   [ ] Termux responsive
-   [ ] Linux compatible
-   [ ] macOS compatible
-   [ ] Tidak ada nested box berlebihan
-   [ ] Startup tetap ringan

------------------------------------------------------------------------

# Final Outcome

Hasil akhir adalah transformasi CLI menjadi **AI Workspace** berbasis
prompt dengan konteks sesi yang selalu terlihat, progres eksekusi yang
transparan, approval yang jelas, dan navigasi cepat melalui command
palette, tanpa mengubah core engine Zsh yang sudah ada.
