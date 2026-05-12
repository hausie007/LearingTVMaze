# Learning Maze - Tester Game Mechanics Overview

## Purpose

This document orients testers who understand game or app testing, but have not played Learning Maze. It explains the mechanics, concepts, and configuration choices to understand before designing or running test scenarios.

It is not a test-case checklist. Use `testing_scenarios.md` for scenario coverage.

## What Learning Maze Is

Learning Maze, also called Bludiste in the project, is an educational maze game for children aged 4 and up. The player navigates a procedurally generated maze using directional controls. Depending on the mission, the maze may be pure navigation or may include educational pickups such as numbers, letters, or letters of a word.

The game is designed for Android phones, tablets, and Google/Android TV. The interaction model is D-pad-first: up, down, left, right, OK, and Back. Touch is supported through an on-screen virtual D-pad, but the game should remain usable without pointer, mouse, swipe, or drag interactions. Menu focus should be visible, predictable, and recoverable.

The experience is intentionally low-pressure. The core solo game does not depend on a fail timer. Children are expected to explore, bump into walls, and correct themselves. The main "failure" state comes from chaser variants, where a chaser catches the collector.

## Core Gameplay Loop

A round starts from the setup flow. The player chooses a mission, optionally chooses a pickup type, then chooses how to play: alone, with a chaser, together, versus a chaser, or as a race. Theme, maze size, learning language, character, and chaser settings can vary the round without changing the basic navigation model.

During gameplay, the maze is grid-based. One successful move advances the avatar by one cell. Walls block movement. When movement is blocked, the player should stay in the same cell and get feedback, such as a shake or haptic response depending on device support.

Most non-race rounds use a start and an exit. In normal maze generation, the player starts near the bottom-left and exits near the top-right. If pickups are required, reaching the exit early is not enough: the player must complete the pickup objective first. Race-style rounds use a different layout: racers start from corners and race toward the center.

## Missions

### Find Exit

Find Exit is the simplest mission. There are no learning pickups. The player navigates from the start to the exit. In solo play this is pure maze navigation. In multiplayer without a chaser, it functions more like a maze race: players compete to reach the exit goal. This mission is useful for isolating maze generation, movement, collision, focus, controls, themes, and device layout without collectible logic.

### Follow Trail

Follow Trail adds visible educational pickups along the maze route. The player must collect them in the correct order. These pickups may be numbers, letters, or word letters. The route objective has two phases: collect the ordered sequence, then finish the maze. If a player reaches the exit before the sequence is complete, the round should not finish yet.

### Find Next

Find Next is also ordered, but it reveals the next required pickup one at a time. After the current target is collected, the next target appears. Placement can be dynamic, especially when chasers or multiple players are involved, so testers should not expect all items to be visible from the beginning.

This mission is useful for testing dynamic goals, HUD/controller instructions, reveals, and stale-target handling.

### Race to Middle

Race to Middle is the main competitive race mode. The maze is generated symmetrically so players starting from different corners have comparable routes to the center. The chaser is forced off. Racers may have no pickups, or they may have race markers based on numbers, letters, or words. To win a race with markers, a player must complete their sequence and then reach the center.

## Pickup Types

### None

No learning items appear. The round is about maze navigation, exit finding, or racing.

### Numbers

Number pickups appear in sequence: 1, 2, 3, and so on. The player is expected to collect them in order. When Voice Hints are enabled and TTS is available on the device, number pickups can be spoken aloud.

### Letters

Letter pickups follow the alphabet for the selected learning language. Most languages use Latin letters, while Greek, Hebrew, and Ukrainian have their own alphabets. Letters are ordered and should be collected in sequence. Voice Hints can speak letter pickups when TTS is available.

### Words

Words mode chooses a word for the selected learning language and difficulty. Each collectible is a character from that word. Spaces are skipped automatically, so multi-word phrases can still be represented as a collection sequence. The HUD tracker shows progress through the word, usually with the associated emoji when available.

Voice Hints can speak collected letters and can also speak the completed word. In short: TTS is not a words-only feature. Numbers, letters, and words can all use voice feedback, subject to device support and the Voice Hints setting.

## Roles and Play Modes

The main role is the collector. A collector explores the maze, completes the pickup objective when one exists, and reaches the exit or finish.

Chaser variants add pressure. In solo chaser mode, the chaser is AI-controlled and pathfinds toward the player after a head-start delay based on chaser speed and difficulty. In multiplayer chaser modes, one player can take the chaser role while another player is the collector.

Racers appear in Race to Middle and some multiplayer exit-race cases. Their HUD treatment emphasizes player badges and progress trackers around the screen edges so the maze center stays readable.

Multiplayer is local-network based. One device is the host and runs the game logic. Other devices can join and act as controllers. Joined phones forward D-pad input to the host and show role-specific goal information.

## Multiplayer: Hosting, Joining, and Emulation

Multiplayer uses a host-authoritative model. The host device creates the session, broadcasts that session on the local network, owns the maze, resolves collisions and pickups, assigns roles, and renders the main game view. Joiner devices are thin controller clients: they choose a character, join the lobby, then forward D-pad input to the host during play. They do not run their own independent copy of the maze simulation.

The normal host flow starts from the setup wizard. Choose a mission and pickup type, then choose a multiplayer action such as Play Together or vs Chaser. The app opens Host Setup, where the host confirms pickup, learning language, character, and chaser/head-start options where applicable. Starting the host opens the Host Lobby.

In the Host Lobby, the host is already occupying one player slot. Empty slots pulse while the app waits for other players. The Start Game button stays disabled until the minimum player count is met. The host also broadcasts discovery while the lobby has room; broadcasting pauses when the lobby is full and stops when the game starts or the session is left.

The normal join flow requires another device on the same local Wi-Fi/network. On the joining device, open Learning Maze and look for the green Join Game / Play Together entry that appears when a host is discovered. Select the host, choose an available character, and press Join Game. After the host starts the round, the joiner enters controller mode: the screen shows a simplified controller UI, character/role information, and the current goal. D-pad input from that device should move its avatar on the host screen.

For local testing without physically joining extra devices, the Host Lobby supports emulated remote players. Focus an empty player slot in the lobby and press OK. The host adds an emulated non-host player using an available character, fills the slot, recalculates roles, and updates the lobby as if another peer had joined. Selecting an occupied non-host slot kicks/removes that player. This is useful for quickly testing lobby capacity, Start Game enablement, player slot rendering, role assignment, race HUD layouts, chaser role setup, and multiplayer game startup.

Emulated players are not full remote clients. They do not exercise UDP discovery, ENet connection setup, Join Flow UI, remote controller mode, remote goal RPC display, phone haptics, disconnect handling from a real client, or actual D-pad input from another device. In gameplay they appear as avatars, but they do not move by themselves because there is no remote input source. Use real devices, or separate running app instances when appropriate for the platform, when the goal is to test discovery, joining, remote controls, network failure behavior, or controller-screen UI.

## Movement, Rules, and Feedback

Movement is discrete and grid-based, but held D-pad input repeats movement after a short cooldown. This is intentional for young players, who often hold a direction instead of tapping repeatedly. The avatar moves one cell per accepted step, with a short visual slide.

Walls are authoritative. If a wall blocks the requested direction, the avatar should not pass through it. The game should give feedback, typically visual shake and, on supported devices, haptics.

Pickup collection is ordered. The currently required number, letter, or word character is the valid target. Touching the wrong ordered item should not advance progress. In Find Next mode, only the next target may exist.

Round completion depends on the mode:

- Normal collector rounds: all required pickups must be collected, then the exit must be reached.
- No-pickup rounds: reaching the exit is enough.
- Chaser rounds: the collector loses the round if caught before completing the objective.
- Race rounds: the winner must complete any required marker sequence and reach the center.
- Some co-op/shared-objective multiplayer flows require all relevant players to finish after the shared objective is complete.

## HUD and End Screens

The HUD is the player's main source of current objective information. It can show mission text, a collectible tracker, player or role badges, race progress rows, and chaser countdown information. Layout changes by mode and player count.

Older planning documents mention a visible timer and move counter in the in-game HUD. Current code comments indicate those visual HUD elements have been removed, so testers should treat the current build as the source of truth. If a timer or move counter is not visible, do not assume it is a regression unless the current product requirement says it should be restored.

When the player wins, the game shows a win screen with options for continuing, changing difficulty, playing together, or adjusting the next round depending on context. When a chaser catches the collector, the result is a Gotcha screen with retry or easier-flow options. Race mode uses race-specific winner presentation.

## Variables Testers Should Keep in Mind

Difficulty changes maze size, from Very Easy at 5 by 4 cells up to Unbelievable at 36 by 15 cells. Race mazes may adjust dimensions to keep symmetric center-based layouts.

Theme changes the visual skin: player, chaser, pickups, start/end markers, walls, floors, colors, and sometimes animation. Theme should not change the rules of the round.

UI language affects app text. Learning language affects alphabets and word lists. These can differ, so a tester may see an English UI while collecting Hebrew letters. Hebrew also matters for right-to-left layout behavior.

Voice Hints depend on both the setting and device TTS availability. If TTS is available, number, letter, and word pickups can produce spoken feedback.

On-screen controls can be off, left-handed, or right-handed, and can change the layout by reserving space for the virtual D-pad. This is especially important on small phones and RTL layouts.

For broad coverage planning, think of a round as a combination of these axes: mission, pickup type, play mode or role, difficulty, theme, learning language, and control layout. Most bugs will show up where two or more of those axes interact.
