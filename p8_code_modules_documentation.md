# PICO-8 Code Modules Documentation
## Dollhouse Leak Fixer Game Architecture

This document explains the different modules and systems within the PICO-8 game code, comparing both the readable development version (`dollhouse_leak_fixer.p8`) and the compressed production version (`dollhouse_leak_fixer_compact.p8`).

## Core Architecture Overview

The game is structured as a state machine with interconnected modules managing different aspects of gameplay. The code follows PICO-8 conventions with global functions for initialization, updates, and rendering.

## Module Breakdown

### 1. Game State Management Module

**Location**: Lines 13-19 (readable) / Lines 5-6 (compact)

**Purpose**: Manages overall game flow and core state variables

**Key Components**:
- `gamestate` / `gs`: Current game state ("playing", "gameover")
- `score` / `sc`: Player's current score based on time survived
- `time_elapsed` / `t`: Global game timer (60fps counter)
- `feedback_msg` / `fm`: UI feedback message display
- `feedback_timer` / `ft`: Timer for feedback message duration

**Functions**:
- `_init()`: Game initialization and setup
- `_update60()`: Main game loop dispatcher (60fps)
- `update_gameover()` / `ugo()`: Game over state handler

### 2. Player System Module

**Location**: Lines 20-29 (readable) / Line 7 (compact)

**Purpose**: Manages player character state, movement, and inventory

**Key Components**:
- Player object `player` / `p` containing:
  - Position: `x`, `y` coordinates
  - Dimensions: `w` (width), `h` (height)
  - Sprite: `sprite` / `s` (sprite ID for rendering)
  - Room tracking: `room` / `r` (current room ID)
  - Inventory: `inventory` / `i` (currently held tool)

**Functions**:
- `update_player()` / `up()`: Handles movement input and boundary checking
- `update_player_room()` / `upr()`: Detects which room player is currently in
- `interact()` / `int()`: Processes tool pickup and usage interactions

### 3. Room System Module

**Location**: Lines 31-38 (readable) / Lines 8-12 (compact)

**Purpose**: Defines the dollhouse layout and individual room properties

**Key Components**:
- Rooms array `rooms` / `rs` with 5 room objects:
  - Kitchen (tool source, no leaks)
  - Bedroom (ceiling leaks: pot/rag)
  - Bathroom (plumbing: wrench/putty)
  - Living room (window cracks: plank/putty)
  - Attic (water tank: wrench/putty, critical multiplier)

**Room Properties**:
- `id` / `i`: Unique room identifier
- `name` / `n`: Room name string
- Position: `x`, `y`, `w`, `h` (layout coordinates)
- `flood_level` / `f`: Current water level (0-20)
- `leak` / `l`: Boolean leak state
- `critical` / `c`: Attic-only flag for global flood multiplier

### 4. Tool System Module

**Location**: Lines 40-44 (readable) / Lines 13-16 (compact)

**Purpose**: Manages tool availability and cycling in kitchen

**Key Components**:
- `tool_types` / `ts`: Array of 5 tool types
- `current_kitchen_tool` / `ct`: Index of currently available tool
- `tool_cycle_timer` / `tct`: Timer for automatic tool cycling
- `tool_cycle_interval` / `tci`: Cycle duration (180 frames = 3 seconds)

**Functions**:
- `can_fix_leak()` / `cfl()`: Validates tool-room compatibility
- `get_correct_tools()` / `gct()`: Returns help text for wrong tool usage
- `fix_leak()` / `fl()`: Applies leak repair and scoring

### 5. Leak Spawning System Module

**Location**: Lines 46-49 (readable) / Lines 15-16 (compact)

**Purpose**: Controls dynamic leak generation and difficulty scaling

**Key Components**:
- `leak_timer` / `lt`: Timer tracking time until next leak
- `leak_interval` / `li`: Current spawn interval (decreases over time)
- `attic_multiplier` / `am`: Global flood rate multiplier (1x normal, 2x with attic leak)

**Functions**:
- `spawn_random_leak()` / `sl()`: Creates new leaks in available rooms
- Difficulty scaling: Reduces spawn interval by 5 frames each cycle (minimum 120 frames)

### 6. Flooding Mechanics Module

**Location**: Lines 51-53 (readable) / Line 16 (compact)

**Purpose**: Handles water level progression and game failure conditions

**Key Components**:
- `flood_rate` / `fr`: Base flooding speed (0.1 units per frame)
- `max_flood_level` / `mf`: Maximum water level (20 units)

**Functions**:
- `update_flooding()` / `uf()`: Increases water levels in rooms with active leaks
- `check_game_over()` / `cgo()`: Monitors for game end condition (4 main rooms fully flooded)

### 7. Rendering System Module

**Location**: Lines 250-369 (readable) / Lines 156-243 (compact)

**Purpose**: Handles all visual output and user interface

**Main Functions**:
- `_draw()`: Main rendering dispatcher
- `draw_game()` / `dg()`: Game state rendering coordinator

**Sub-modules**:

#### House Visualization (`draw_house()` / `dh()`)
- Renders dollhouse outline and room dividers
- Displays room labels and current kitchen tool

#### Leak Indicators (`draw_leaks()` / `dl()`)
- Shows leak locations with colored circles
- Attic leak warning with blinking exclamation mark

#### Flooding Visualization (`draw_flooding()` / `df()`)
- Renders water levels as blue rectangles
- Proportional height based on current flood level

#### HUD System (`draw_hud()` / `dhud()`)
- Score display
- Current inventory item
- Feedback messages with color coding (green=success, red=error)
- Attic leak warning
- Room flood level bars

#### Game Over Screen (`draw_gameover()` / `dgo()`)
- Final score display
- Restart instructions

### 8. Audio System Module

**Location**: Lines 144, 153, 157 (readable) / Lines 80, 87, 91 (compact)

**Purpose**: Provides audio feedback for player actions

**Sound Effects**:
- `sfx(0)`: Tool pickup confirmation
- `sfx(1)`: Successful leak repair
- `sfx(2)`: Wrong tool error sound

### 9. Game Logic Integration Module

**Location**: Lines 68-102 (readable) / Lines 27-48 (compact)

**Purpose**: Coordinates all systems in the main game loop

**Main Function**: `update_game()` / `ug()`

**Responsibilities**:
- Timer management and score calculation
- Tool cycling coordination
- Leak spawning with difficulty progression
- Player input processing
- Flooding progression
- Game over detection

## Code Organization Patterns

### Variable Naming Convention
- **Readable version**: Descriptive names (`gamestate`, `flood_level`, `current_kitchen_tool`)
- **Compact version**: Abbreviated names (`gs`, `f`, `ct`) to meet PICO-8's 8KB limit

### Function Architecture
- **Modular design**: Each system has dedicated update and rendering functions
- **State management**: Clear separation between game states and transitions
- **Input handling**: Centralized button processing with action delegation

### Data Structure Design
- **Object-oriented approach**: Player and room objects with encapsulated properties
- **Array-based systems**: Rooms and tools stored in indexed arrays for iteration
- **State flags**: Boolean properties for leak detection and game flow control

## System Interdependencies

1. **Player ↔ Room System**: Player position determines current room for interaction context
2. **Tool System ↔ Leak System**: Tool compatibility validation prevents incorrect repairs
3. **Leak System ↔ Flooding System**: Active leaks drive water level progression
4. **Flooding System ↔ Game State**: Flood levels determine game over conditions
5. **All Systems ↔ Rendering**: Every system has corresponding visual representation
6. **Timer System**: Global frame counter synchronizes tool cycling, leak spawning, and difficulty scaling

## Performance Considerations

- **Memory efficiency**: Compact version reduces variable names and whitespace
- **Frame-based timing**: All timers use 60fps frame counting for consistent behavior
- **Efficient collision detection**: Simple bounding box checks for room detection
- **Minimal graphics**: Basic shapes and sprites to stay within PICO-8 constraints