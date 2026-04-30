# Bludiste — Game Overview

## Target audience
**Age range:** 4+ (toddlers and early primary school children)
**Reading ability:** Pre-reader to early reader; game works without any reading ability (icon-driven navigation, TTS voice hints, visual collectibles)
**Expected adult involvement:** Low — the setup wizard is designed for 2-tap instant play with sensible defaults, but a parent may assist very young children with initial configuration (language, difficulty)

---

## Platform
**Smart TV / Chromecast / Android TV:** Google TV (Android TV) is a primary target; also ships as Android APK/AAB for phones and tablets
**Input devices:**
- Google TV: IR remote (D-pad + OK + Back)
- Android phone/tablet: on-screen virtual D-pad (touch), configurable left/right-handed
- No pointer / mouse interaction required on any platform

**Phone controller tech:** After joining a multiplayer session, the phone acts as a pure D-pad controller. Input is forwarded over WiFi to the host device via `NetworkManager.send_dpad()` (UDP). The joiner never runs game logic locally.

---

## Core loop
**Player does:**
1. Choose mission, pickup type, and play mode in the 3-step setup wizard (2–3 taps with defaults)
2. Navigate a procedurally generated maze using the D-pad
3. Collect educational items (numbers, letters, or letters of a word) in the correct order
4. Reach the exit to win (or avoid the chaser)

**Player learns:**
- Letter recognition and alphabet order (21 languages; Latin, Greek, Hebrew, Ukrainian alphabets)
- Number recognition and counting order
- Spelling: collecting letters one at a time to form a word (shown with emoji + spoken by TTS)
- Spatial orientation and maze navigation
- Remote/D-pad control skills (directional input, OK, Back)

**Level ends when:**
- All collectibles have been gathered and the player reaches the exit → **Win**
- The chaser catches the player → **Gotcha** (prompt to try again or go easier)
- Race mode: first player to reach the centre cell wins

---

## Game modes
**Solo:** Single player navigates the maze alone, with or without a chaser enemy and with or without educational collectibles

**Multiplayer:** 2–4 players over local WiFi. One device hosts the game (runs all logic); others join and use their phones as D-pad controllers. Discovered automatically via UDP broadcast — no setup code or pairing required.

**Co-op or competitive:**
- *Co-op:* Collector + Chaser on the same session (one collects, one tries to catch — roles can be swapped after a round)
- *Competitive:* Race to Middle — each player races to the centre cell via sequential waypoints; first to arrive wins
- *Friendly Chaser:* togglable; chaser can be disabled for a fully co-operative "explore together" experience

---

## Learning goals
**Letters:** Alphabet collectibles (A–Z, Α–Ω, א–ת, А–Я) spawn in order; collecting each one lights it up in the HUD and the TTS speaks it aloud

**Numbers:** Sequential number collectibles (1, 2, 3 …); same HUD and TTS announcement mechanic

**Spelling:** "Follow Trail" and "Find Next" missions — each collectible is one letter of a target word; the full word appears in the HUD letter-by-letter; the emoji + TTS reinforce word meaning

**Maze/orientation:** Every play session builds directional thinking (up/down/left/right navigation), dead-end recognition, and short-term spatial memory in a low-pressure environment

**Remote-control skills:** All interaction is intentionally D-pad-only; children practice the exact input model used on Smart TVs and set-top boxes (directional navigation, OK to confirm, Back to go back)

---

## Current concerns
**What feels weak:** *(to be filled in by the team — e.g., onboarding clarity for first-time users, difficulty curve for the youngest age group, multiplayer discoverability on first use)*

**What users struggled with:** *(to be filled in after user testing — e.g., understanding the join flow on phone, knowing which direction to go in large mazes, distinguishing chaser from player)*

**What you want reviewed most:** *(to be filled in — suggested candidates: the 3-step wizard for 4-year-olds, TTS language accuracy, chaser head-start balance)*

---

## Known constraints
**Godot version:** 4.6 (Mobile rendering profile; Jolt Physics)

**Target devices:**
- Android phones and tablets (APK / AAB)
- Google TV / Android TV (same APK, exported with Leanback banner)
- No iOS target currently

**Performance limitations:**
- Mobile renderer (not Vulkan forward+); glow/bloom settings are per-theme and kept conservative
- Maze generation is iterative DFS (avoids recursion stack overflow on large grids up to 36×15)
- All multiplayer game logic runs on the host; joiner devices are intentionally thin clients

**TTS implementation:** Godot's built-in `DisplayServer.tts_speak()` on a background thread (`tts_manager.gd`). Availability is checked at runtime; the Voice Hints setting is disabled and dimmed when TTS is unavailable on the device.

**Languages supported:** 21 UI languages (cs, de, en, es, fr, it, nl, pl, pt, sv, nb, da, fi, hu, ro, tr, vi, sk, uk, el, he). The same 21 languages are available as independent **learning languages** (what the collectibles teach). RTL layout is applied automatically for Hebrew.
