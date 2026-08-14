# AI-FIRST UX REFACTOR BLUEPRINT --- Bagas AI CLI v2

> **Project:** `zsh_bagas-ui-fixed-2`
>
> **Focus:** Mengubah seluruh pengalaman pengguna menjadi **AI
> Workspace**, bukan kumpulan menu (AI Chat, AI Long, AI Agent, Code,
> Project).
>
> **Constraint:** Tidak mengubah engine (`dispatcher`, `workflow`,
> `subagent`, `tool registry`). Hanya refactor layer UI (`30-ai/60-ui`)
> dan flow interaksi.

------------------------------------------------------------------------

# Executive Summary

## Masalah utama

Arsitektur teknis sudah modular, tetapi UX masih mengikuti paradigma
lama:

> **Menu → Pilih fitur → Jalankan command**

Padahal AI CLI modern (Claude Code, Gemini CLI, OpenCode) menggunakan
paradigma:

> **Prompt → AI menentukan mode → UI berubah mengikuti state**

Akibatnya:

-   AI Chat terlalu verbose.
-   AI Long terasa seperti aplikasi berbeda.
-   AI Agent hanya menampilkan log step.
-   Session tersembunyi di menu.
-   User harus memilih fitur sebelum bekerja.

## Target

Semua interaksi masuk melalui **satu prompt utama**.

``` text
Bagas AI

> fix authentication bug
```

AI otomatis memilih mode yang tepat.

------------------------------------------------------------------------

# Paradigma Baru

## Sebelum

``` text
Main Menu

1 Chat
2 Long Chat
3 Session
4 AI Agent
5 Generate
6 Edit
7 Scan
...
```

User harus menentukan mode.

## Sesudah

``` text
Bagas AI

> buat proposal AI
```

AI menentukan mode.

  Prompt            Mode
  ----------------- ---------
  `jelaskan JWT`    Chat
  `buat proposal`   Long
  `fix auth`        Agent
  `edit file`       Code
  `scan project`    Project

Mode menjadi **state**, bukan menu.

------------------------------------------------------------------------

# UX State Machine

Seluruh aplikasi hanya memiliki satu workspace.

``` text
Idle

↓

Thinking

↓

Acting

↓

Waiting Approval

↓

Done
```

Mode Chat, Long, Agent, Code, dan Project hanya mengubah tampilan state
tersebut.

------------------------------------------------------------------------

# Universal Layout

Semua mode memakai layout yang sama.

``` text
Header

Conversation

Status Line

Prompt
```

## Header

``` text
Bagas AI

main • GPT-5.6 • ~/project
24k token
```

Header selalu tampil.

Tidak ada menu Session lagi.

------------------------------------------------------------------------

## Conversation

Chat selalu ringkas.

``` text
> jelaskan JWT

JWT adalah token...

⏱ 1.2s • GPT-5.6
```

Tidak ada hero box di setiap jawaban.

------------------------------------------------------------------------

## Status Line

Menggantikan box.

### Lama

``` text
╭────────╮
│ Status │
╰────────╯
Searching...
```

### Baru

``` text
● Searching...
```

Atau

``` text
✓ Done
```

Hemat beberapa baris setiap aksi.

------------------------------------------------------------------------

## Prompt

Selalu tetap.

``` text
> _
```

------------------------------------------------------------------------

# AI Chat Redesign

## Masalah

AI Chat terlalu verbose.

Setiap respons menghabiskan banyak ruang.

## Target

``` text
> apa itu JWT

JWT adalah token...

⏱ 1.2s
```

### Rules

-   Hero box hanya saat startup.
-   Timestamp kecil.
-   Model inline.
-   Divider tipis.
-   Tidak ada box berulang.

------------------------------------------------------------------------

# AI Long Redesign

AI Long bukan lagi menu.

AI Long menjadi **Conversation Mode**.

## Flow

``` text
> tulis proposal AI

Planning...
Writing...
Review...
Done
```

## UI

``` text
Proposal AI

Mode: Writing

Progress 2/5

✓ Outline
✓ Draft
● Refinement
○ Review
○ Final
```

User tetap berada di workspace yang sama.

------------------------------------------------------------------------

# AI Agent Redesign

Ini menjadi pengalaman paling kaya.

## Idle

``` text
> _
```

## Thinking

``` text
Thinking...

Searching files...
```

## Acting

``` text
Using rg

Found 24 files
```

## Approval

``` text
Needs approval

rm build/

Approve Deny
```

## Done

``` text
Done

3 files changed
42s
```

Agent menjadi state machine yang jelas.

------------------------------------------------------------------------

# Code Mode

Code Mode bukan aplikasi terpisah.

## Sebelum

Generate Code

↓

Edit

↓

Fix

↓

Review

## Baru

``` text
> fix auth bug

Planning...

Editing...

Testing...

Done.
```

### UI

``` text
Current Task

Editing auth.ts

✓ Search
✓ Open file
● Edit
○ Test
○ Summary
```

------------------------------------------------------------------------

# Project Mode

## Flow

``` text
> scan project
```

### UI

``` text
Project Scan

247 files

Scanning...

█████████░░░░

✓ Git
✓ Dependencies
● Indexing
○ Summary
```

Tidak perlu kembali ke menu.

------------------------------------------------------------------------

# Session Menjadi Context Bar

Sekarang Session adalah menu.

Targetnya selalu terlihat.

``` text
main • GPT-5.6 • ~/project

dirty
3 files changed
24k token
```

Data berasal dari:

-   Git
-   Session Manager
-   Model Config

------------------------------------------------------------------------

# Verbosity System

Ini fitur paling penting.

## Level 0 --- Minimal (Default HP)

``` text
> fix auth

Done.

3 files changed.
```

## Level 1 --- Normal

``` text
Searching...

Editing...

Done.
```

## Level 2 --- Detailed

``` text
Tool: rg

Opening...

Editing...
```

## Level 3 --- Debug

Semua log internal.

Command:

``` text
/config verbosity 0
/config verbosity 1
/config verbosity 2
/config verbosity 3
```

------------------------------------------------------------------------

# Progressive Disclosure

AI tidak langsung membuka semua detail.

## Default

``` text
Searching auth...
```

Kalau user ingin detail.

``` text
/details
```

Baru tampil:

``` text
Tool: rg

24 matches

Files...
```

------------------------------------------------------------------------

# Command Palette

Launcher modern menggantikan menu panjang.

Shortcut:

``` text
Ctrl+P
```

atau

``` text
/
```

UI

``` text
Search command...

Chat

Generate Code

Fix Project
```

Implementasi memakai `gum filter`.

------------------------------------------------------------------------

# Information Hierarchy

## Hero

Hanya satu.

``` text
Bagas AI
```

## Section

Divider.

``` text
────────────
```

## Item

Indent.

Tidak ada nested box.

------------------------------------------------------------------------

# Mockup Final

## Home

``` text
┌──────────────────────────┐
│ Bagas AI        READY     │
│ GPT-5.6 • main           │
├──────────────────────────┤
│ > fix auth bug           │
├──────────────────────────┤
│ Recent: auth-api         │
│ Workspace: ~/backend     │
└──────────────────────────┘
```

## Agent Running

``` text
┌──────────────────────────┐
│ AI Agent      RUNNING    │
├──────────────────────────┤
│ Progress 4/7             │
│ ██████████░░             │
├──────────────────────────┤
│ ✓ Search                 │
│ ✓ Open                   │
│ ● Edit                   │
│ ○ Test                   │
│ ○ Report                 │
└──────────────────────────┘
```

## Final Report

``` text
┌──────────────────────────┐
│ SUCCESS                  │
├──────────────────────────┤
│ Files: 3                 │
│ Time: 42s                │
├──────────────────────────┤
│ ✓ JWT fixed              │
│ ✓ Tests passed           │
└──────────────────────────┘
```

------------------------------------------------------------------------

# Mapping ke Struktur Proyek

## Tidak Diubah

-   `40-dispatcher.zsh`
-   `55-subagent`
-   `40-workflow`
-   `05-tools`

## Refactor Prioritas

  File                      Tujuan
  ------------------------- ---------------------
  `20-menu.zsh`             Single Prompt Entry
  `05-ui_box.zsh`           Minimal layout
  `35-update_confirm.zsh`   Approval Card
  `20-session_mgmt.zsh`     Sticky Header
  `20-chat/*`               Compact Chat
  `25-project_report.zsh`   Final Summary

------------------------------------------------------------------------

# Roadmap

## Phase 1 --- AI Workspace

-   [ ] Single prompt entry.
-   [ ] Sticky header.
-   [ ] Compact chat.

## Phase 2 --- State UI

-   [ ] Thinking state.
-   [ ] Acting state.
-   [ ] Approval state.
-   [ ] Done state.

## Phase 3 --- Verbosity

-   [ ] Level 0.
-   [ ] Level 1.
-   [ ] Level 2.
-   [ ] Level 3.

## Phase 4 --- Progressive Disclosure

-   [ ] `/details`
-   [ ] Lazy tool logs.
-   [ ] Compact default output.

## Phase 5 --- Polish

-   [ ] 80-column Termux.
-   [ ] 120-column Desktop.
-   [ ] Consistent spacing.
-   [ ] Performance tetap ringan.

------------------------------------------------------------------------

# Acceptance Criteria

## User Experience

-   Tidak perlu memilih Chat, Long, atau Agent.
-   Semua task dimulai dari prompt.
-   AI memilih mode otomatis.
-   Session selalu terlihat.
-   Output default hemat layar.

## Technical

-   Tidak mengubah engine.
-   Kompatibel dengan Gum.
-   Startup tetap cepat.
-   Semua command lama tetap berfungsi melalui dispatcher.
