# PICO-8 Development Plan for "Dollhouse Leak Fixer"

## Game Architecture Overview

**Core Systems:**
- **Player System**: 4-directional movement, single-item inventory
- **House System**: 5-room dollhouse cutaway view (Kitchen, Bedroom, Bathroom, Living Room, Attic)
- **Leak System**: Random spawn, room-specific types, escalating difficulty
- **Tool System**: Kitchen production line, 5 tool types with specific uses
- **Flooding System**: Per-room water levels, visual indicators, room lockout
- **HUD System**: Score, inventory display, flood meters, attic warning

## Technical Considerations for PICO-8

**Memory Constraints:**
- 128x128 pixel display (perfect for dollhouse view)
- 16-color palette (retro aesthetic matches ZX Spectrum inspiration)
- 8KB code limit (requires efficient Lua coding)
- 128 8x8 sprites available

**Input Mapping:**
- Arrow keys: Player movement
- ❎ (X) button: Pick up/use items
- 🅾️ (O) button: Unused (potential pause/menu)

## Development Phases

### Phase 1: Core Framework
1. **Project Setup** - Initialize cart, basic game loop ✓
2. **Sprite Assets** - Player character, 5 tools, house layout tiles ✓
3. **Player Movement** - 4-directional movement with room boundaries ✓

### Phase 2: House & Rooms  
4. **House Layout** - Cutaway dollhouse view, room definitions ✓
5. **Room System** - Player-room interaction, navigation between areas ✓

### Phase 3: Game Mechanics
6. **Inventory System** - Single item carry, pickup/drop mechanics ✓
7. **Tool Spawning** - Kitchen production line with random cycling ✓
8. **Leak System** - Random spawn timing, room-specific leak types ✓

### Phase 4: Core Gameplay
9. **Flooding Mechanics** - Water level tracking, visual indicators ✓
10. **Repair System** - Tool-leak matching, temporary vs permanent fixes ✓
11. **Attic Priority** - Critical leak that accelerates house flooding ✓

### Phase 5: Polish & Balance
12. **HUD Implementation** - Score, inventory, flood meters, warnings ✓
13. **Game States** - Start screen, game over, victory conditions ✓
14. **Audio & Balance** - SFX, music, difficulty tuning ✓

## Key PICO-8 Implementation Details

**Room Layout**: Use map data for dollhouse rooms, each 32x24 pixels
**Flooding Visual**: Animated blue sprites rising from room floor
**Tool Cycling**: Timer-based random tool spawning in kitchen
**Leak Types**: Simple sprite overlays with room-specific logic
**Score System**: Time-based survival scoring with leak fix bonuses

## Game Design Implementation

Based on the original design document, the following mechanics have been implemented:

### Core Mechanics
- ✅ Four-directional player movement (left, right, up, down)
- ✅ Single button interaction to pick up and release/use objects
- ✅ One-item inventory system
- ✅ Fix leaks in different rooms using appropriate tools

### Objects & Fixing Tools
- ✅ **Cooking Pot**: Catches drips temporarily
- ✅ **Adhesive/Putty**: Seals cracks or pipes
- ✅ **Wrench**: Tightens valves or bolts
- ✅ **Rag/Cloth**: Absorbs small leaks
- ✅ **Wooden Plank**: Covers holes or cracks

### Rooms & Leak Scenarios
- ✅ **Kitchen**: Produces random tools for collection
- ✅ **Bedroom**: Ceiling leaks; fixed with pot or rag
- ✅ **Bathroom**: Pipe bursts; fixed with wrench or adhesive
- ✅ **Living Room**: Window cracks; fixed with plank or adhesive
- ✅ **Attic**: Critical water tank leaks; fixed with wrench or adhesive

### Flooding Mechanic
- ✅ Each room has visual flood meter (rising water)
- ✅ Water level increases over time if leak not fixed
- ✅ Rooms become unusable when fully flooded
- ✅ Attic leaks accelerate flooding in all rooms

### Victory & Defeat Conditions
- ✅ Endless survival mode with time-based scoring
- ✅ Defeat when all four main rooms are completely flooded

### HUD & Interface
- ✅ Score display (survival time + leak fixes)
- ✅ Current carried item display
- ✅ Flood indicators for each room
- ✅ Kitchen tool availability display
- ✅ Attic warning system (blinking indicator)

### Game Loop Implementation
1. ✅ Random leak appears in rooms
2. ✅ Player travels to kitchen to grab tools
3. ✅ Player travels to leaking room and uses appropriate tool
4. ✅ New leaks spawn randomly with increasing frequency
5. ✅ Player prioritizes leak repairs
6. ✅ Flooding escalates until rooms lock out
7. ✅ Game ends when all main rooms are flooded

## Technical Architecture

### Data Structures
```lua
-- Player object with position, room tracking, and inventory
player = {x, y, w, h, sprite, room, inventory}

-- Room system with flood levels and leak states
rooms = {id, name, x, y, w, h, flood_level, leak, critical}

-- Tool management system
tool_types = {"pot", "putty", "wrench", "rag", "plank"}
```

### Key Systems
- **Movement System**: Boundary checking and room detection
- **Interaction System**: Context-sensitive pickup/use mechanics
- **Flooding System**: Progressive water level visualization
- **Leak Spawning**: Difficulty-scaled random generation
- **Tool Compatibility**: Room-specific repair logic

## Performance Considerations

The implementation leverages PICO-8's strengths while working within constraints:
- Efficient sprite-based graphics for house layout
- Simple collision detection for room boundaries
- Timer-based systems for leak spawning and tool cycling
- Minimal memory footprint with compact data structures
- Retro aesthetic that matches the ZX Spectrum inspiration

## Future Enhancement Possibilities

- Additional tool types and room variations
- Power-ups or temporary abilities
- Multi-story house expansion
- Seasonal weather effects affecting leak frequency
- Achievement system for various survival milestones

---

**Status**: Complete implementation ready for PICO-8 deployment
**File**: `dollhouse_leak_fixer.p8`
**Target Platform**: PICO-8 Fantasy Console