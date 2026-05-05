# Learning Maze — Game Design & UX Specification (v3)

## 1. Executive Summary & Game Identity
**Learning Maze (Bludiste)** is an educational maze game specifically designed for children aged 4+, built in Godot 4.6. The game targets a wide array of devices including Android phones, tablets, and Google TV. 

**End-User Perspective:** The core experience is designed to be accessible, immediate, and frustration-free for young players. It combines spatial navigation (mazes) with optional educational collectibles (numbers, letters, words in 21 languages). Whether playing solo or with family via local WiFi multiplayer, the game focuses on intuitive controls, clear visual feedback, and a welcoming environment that encourages learning without penalty.

---

## 2. Gaming Mechanics & End-User Experience

### 2.1 Core Gameplay Loop
The player navigates a procedurally generated maze from a starting point to an exit. Along the way, they may need to collect educational items. The game provides continuous visual and haptic feedback to keep the child engaged.
- **Movement:** Continuous movement upon holding a direction (poll-based with cooldowns), as children naturally hold down buttons rather than tapping them. Wall bumps trigger a slight screen shake and haptic feedback to indicate a blocked path.
- **Goal Completion:** Once all required collectibles are gathered, the player must reach the exit. 
- **No Time Pressure:** There are no failing timers. The player is encouraged to explore and learn at their own pace.

### 2.2 Roles & Game Modes
- **Collector (Solo/Co-op):** The primary role. The player explores the maze, gathers specified collectibles (numbers, letters, or spelling words), and finds the exit.
- **Chaser (Multiplayer/Solo vs AI):** A competitive element where a chaser tries to catch the Collector. The Chaser is released after a "Head Start" delay, giving the Collector time to progress.
- **Racer (Multiplayer):** In a 3-4 player setup, players race against each other to a center point, collecting waypoints sequentially.

### 2.3 Missions & Educational Pickups
- **Missions:** 
  - *Find Exit:* Pure spatial navigation.
  - *Follow Trail / Find Next:* Focus on collecting items in sequence.
  - *Race to Middle:* Pure competitive multiplayer navigation.
- **Pickups:**
  - *None:* Just the maze.
  - *Numbers:* Sequential counting.
  - *Letters/Words:* Alphabet learning and spelling (with TTS pronunciation and emoji associations). 

### 2.4 Difficulty Progression
The game scales dynamically across 7 levels (Very Easy 5x4 to Unbelievable 36x15). The difficulty affects the grid size and complexity, allowing the game to grow with the child's cognitive abilities.

---

## 3. UI Navigation & Menu Paths

Every menu is designed around **Progressive Disclosure**, meaning the user is only asked to make one choice at a time. This prevents cognitive overload for young players.

### 3.1 Game Setup Wizard (Main Menu)
This is the canonical home screen. It uses a 3-step wizard to lead the user into the game.

#### **Step 1: Mission Selection**
- **What they see:** A row of large, colorful cards representing different mission types (Find Exit, Follow Trail, etc.). Below the cards are Theme and Maze Size selectors.
- **Why it's important:** It sets the core objective immediately. The default is always valid, so a child can just press "OK" to start playing.
- **Navigation:** If a local multiplayer host is found, a green "Play Together" card is dynamically inserted in the middle. Selecting a card collapses Step 1 into a small breadcrumb summary (e.g., "▾ Follow Trail") and opens Step 2.

#### **Step 2: Pickup Selection**
- **What they see:** Cards for Numbers, Words, Letters, or Just Maze, filtered to only show valid options for the chosen mission. A Language selector appears below if applicable.
- **Why it's important:** Customizes the educational content based on what the child wants to learn.
- **Navigation:** Pressing a card collapses Step 2 and opens Step 3. If a mission only has one valid pickup (like Find Exit -> None), this step is automatically skipped.

#### **Step 3: Play Mode**
- **What they see:** Cards split into Single Player (`[Play Alone]`, `[+ Chaser]`) and Multiplayer (`[Play Together]`, `[vs Chaser]`). Below are Character and Chaser Speed selectors.
- **Why it's important:** Finalizes how the game is played and with whom.
- **Navigation:** Pressing an action card either instantly starts a Solo game or transitions to the Multiplayer Host Setup.

### 3.2 Multiplayer Flow

#### **Host Setup & Lobby**
- **What the host sees:** A setup screen to finalize the game settings, followed by a Lobby showing connected players as character portraits. A localized "How to Join" banner gives clear instructions.
- **Why it's important:** Provides a safe, enclosed waiting room before the game starts, ensuring everyone is ready.
- **Navigation:** The host waits for slots to fill (visualized by pulsing borders becoming solid), then presses "Start Game".

#### **Joiner Flow & Controller Mode**
- **What the joiner sees:** 
  1. *Join Setup:* A screen showing the host's game info and character selection.
  2. *Controller Mode:* Once the game starts, the joiner's screen strips away all UI except for their character icon, a large colored D-Pad, and their current goal (e.g., "Collect all letters").
- **Why it's important:** By turning the secondary device into a pure remote controller, it keeps the players' eyes on the main screen (TV/Tablet) while providing an immersive, distraction-free interface in their hands.

### 3.3 In-Game HUD & End Screens

- **In-Game HUD:** Displays a timer, move count, and collectible progress (e.g., dimmed letters that light up and bounce when collected). Multi-step dynamic goals text updates as the player progresses.
  - *Race Mode HUD:* Optimized for 3-4 players by moving large player badges to the screen edges with dedicated status trackers, preventing center-screen clutter.
- **Win/Gotcha Screens:** Rendered in a cohesive parchment aesthetic. 
  - *Win:* Shows "You Win!", time/moves, and offers quick actions like "Next Round" or "Harder".
  - *Gotcha:* Shows if caught by a chaser. Offers "Try Again" or "Easier".
  - *Why it's important:* Provides immediate, positive reinforcement or gentle encouragement, with an auto-countdown that proceeds to the next round if no input is given, maintaining the play loop without requiring reading or explicit selection.

---

## 4. Design Choices & Navigation Focus

### 4.1 D-Pad First & Focus-Driven Philosophy
The game is built entirely around D-Pad operability (4 directions + OK + Back). No pointer or touch swipe is required, though touch is supported.
- **Why:** On Google TV, remote controls are the only input. For children, discrete directional presses are often easier to conceptualize than drag-and-drop or swiping.
- **Implementation:** Every screen transition ends with an explicit `grab_focus()`. Focus neighbors are manually wired to ensure the cursor never gets "lost" or trapped in a dead end.

### 4.2 OLED Burn-in Protection
TVs and modern phones are susceptible to OLED burn-in from static UI elements (like D-Pads or Lobby screens).
- **Design Choice:** An `IdleManager` consistently tracks user input. If inactivity is detected, the screen automatically dims. Any input (D-Pad press, HUD interaction) instantly resets the timer and restores full brightness.

### 4.3 Responsive Layouts & Accessibility
- **Layout Shifting:** When the virtual D-Pad is active, the game automatically reserves 25% of the screen width (left or right) and shifts all content into the remaining space to prevent UI overlap.
- **RTL (Right-to-Left) Support:** For languages like Hebrew, the layout direction reverses, the D-pad zone mirrors, and UI elements flip to maintain natural reading and interaction flow.
- **Accessibility:** High contrast colors, large targets (buttons ≥220x52px), and Text-to-Speech (TTS) for word spelling and help slides ensure the game is usable by children who cannot read yet.

---

## 5. Technical Section: Developer Choices

### 5.1 Input & Autoload Architecture
- **Virtual D-Pad (`DPad` singleton):** A CanvasLayer on layer 150 ensures controls are always on top. It uses `TouchScreenButton` nodes to emulate hardware D-Pad presses (`ui_up`, `ui_down`, etc.), standardizing input across platforms.
- **Autoloads:** State management is decoupled from scenes. 
  - `Config`: Persists settings and handles difficulty logic.
  - `NetworkManager`: Abstracts UDP broadcasting and RPC calls.

### 5.2 Dynamic Goals & Multi-Step Instructions
- **Architecture:** Instead of hardcoded strings, the game uses a dynamic goal system. The host evaluates the game state (e.g., "all items collected") and sends an RPC (`rpc_update_remote_goal`) to all joiners with a translation key. 
- **Developer Choice:** This minimizes network traffic (sending a short state key rather than continuous string updates) while ensuring all devices (host HUD and remote controllers) instantly update to show the next objective (e.g., switching from "Collect" to "Find Exit").

### 5.3 Scene Flow & Memory Management
- **Flow:** `splash.tscn` → `game_setup_wizard.tscn` → `main.tscn` / `multiplayer_game.tscn`. 
- **Developer Choice:** Keeping the wizard and the game in separate scenes ensures clean memory management. The wizard is unloaded during gameplay to free resources, and the `Config` singleton carries the necessary state between them.

### 5.4 Theming Architecture
- **Implementation:** Themes are directory-based with a `manifest.json` defining textures, colors, and glow settings. `ThemeLoader` caches these at runtime.
- **Developer Choice:** This data-driven approach allows for rapid addition of new visual styles (e.g., "Space", "Jungle", "Parchment") without altering game logic. The `CharacterCatalog` dynamically builds a flat list of all characters across available themes, simplifying the character selection UI.

### 5.5 Networking Paradigm
- **Architecture:** The host acts as the authoritative server. Joiner devices in "Controller Mode" are essentially thin clients; they do not run game logic. They forward `ui_*` inputs via `NetworkManager.send_dpad()` to the host.
- **Developer Choice:** This solves synchronization issues inherently. By rendering the maze and resolving collisions only on the host (usually a powerful TV or Tablet), the joiner's device (a phone) uses minimal battery and never suffers from desync.
