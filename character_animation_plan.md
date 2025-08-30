# Character Walking Animation Implementation Plan

## Overview
This document outlines the implementation of character walking animations for the Dollhouse Leak Fixer PICO-8 game. The system will use 2-frame walking animations for left and right movement directions.

## Current System Analysis

### Existing Player Structure
```lua
player = {
  x = 56,           -- position (centered on ladder)
  y = 96,           -- starting at ground level
  w = 16,           -- player sprite width (16x16)
  h = 16,           -- player sprite height
  sprite_tl = 1,    -- top-left sprite (current: static)
  sprite_tr = 2,    -- top-right sprite
  sprite_bl = 17,   -- bottom-left sprite
  sprite_br = 18,   -- bottom-right sprite
  room = 0,         -- current room id
  inventory = nil   -- currently held tool
}
```

### Current Movement System
- Uses `btn(0)` for left movement, `btn(1)` for right movement
- Updates player.x coordinates directly
- No animation state tracking

### Current Drawing System
- Uses 2x2 sprite composition with four 8x8 sprites
- Static sprite references in `draw_player()` function

## New Animation System Design

### Sprite Mapping
Based on the 6 character sprites from `character-sprites.png`:

| Animation State | Frame | Top-Left | Top-Right | Bottom-Left | Bottom-Right |
|----------------|-------|----------|-----------|-------------|--------------|
| Walking Right  | 1     | 0        | 1         | 16          | 17           |
| Walking Right  | 2     | 2        | 3         | 18          | 19           |
| Walking Left   | 1     | 4        | 5         | 20          | 21           |
| Walking Left   | 2     | 6        | 7         | 22          | 23           |
| Front Facing   | -     | 8        | 9         | 24          | 25           |
| Back Facing    | -     | 10       | 11        | 26          | 27           |

### Enhanced Player Structure
```lua
player = {
  -- Existing properties
  x = 56,
  y = 96,
  w = 16,
  h = 16,
  room = 0,
  inventory = nil,
  
  -- New animation properties
  anim_state = "idle",      -- idle, walking_left, walking_right
  anim_frame = 1,           -- current animation frame (1 or 2)
  anim_timer = 0,           -- frame timing counter
  anim_speed = 15,          -- frames per animation frame (15 = ~4fps at 60fps)
  last_direction = "right"  -- remember last direction for idle pose
}
```

## Implementation Steps

### Step 1: Update Player Object
- Add animation variables to player table
- Remove static sprite references (sprite_tl, sprite_tr, etc.)
- Set default animation state

### Step 2: Create Animation System Functions

#### `update_player_animation()`
- Increment animation timer
- Switch animation frames based on timing
- Handle frame cycling (1 → 2 → 1)

#### `get_player_sprites()`
- Return sprite IDs based on current animation state and frame
- Map animation states to sprite combinations
- Handle idle states with last direction

### Step 3: Update Movement Logic
- Detect movement in `update_player()`
- Set appropriate animation state when moving
- Reset to idle when no movement detected
- Track last movement direction

### Step 4: Update Drawing System
- Modify `draw_player()` to use dynamic sprite selection
- Call `get_player_sprites()` for current sprite IDs
- Maintain 2x2 sprite composition structure

## Technical Details

### Frame Timing
- 60 FPS PICO-8 game loop
- Animation speed of 15 frames = ~4 FPS animation
- 2-frame walking cycle = ~0.5 seconds per full cycle

### Animation States
- **idle**: Uses frame 1 of last walking direction
- **walking_left**: Alternates between left frames 1 and 2
- **walking_right**: Alternates between right frames 1 and 2

### Sprite ID Calculation
```lua
-- Walking Right Frame 1: sprites 0,1,16,17
-- Walking Right Frame 2: sprites 2,3,18,19
-- Pattern: base_sprite = (direction_offset + (frame-1) * 2)
```

## Future Enhancements
- Front/back facing animations for vertical movement
- Idle animations with subtle movement
- Tool-holding animation variants
- Animation speed adjustments based on movement speed

## Testing Checklist
- [ ] Character animates when walking right
- [ ] Character animates when walking left  
- [ ] Animation stops when movement stops
- [ ] Frame timing feels natural
- [ ] No visual glitches in sprite composition
- [ ] Animations work in all rooms
- [ ] Performance impact is minimal

## Memory Considerations
- Additional variables add ~40 bytes to player object
- Animation functions add ~200-300 bytes of code
- Well within PICO-8's 8KB code limit
- No additional graphics memory required (using existing sprites)