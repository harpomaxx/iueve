# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains "Dollhouse Leak Fixer," a retro-inspired game for the PICO-8 fantasy console. The game implements a ZX Spectrum-style dollhouse cutaway view where players fix water leaks across 5 rooms using appropriate tools.

## PICO-8 Development Commands

### Running the Game
- Load in PICO-8: `load dollhouse_leak_fixer_compact.p8`
- Run: `run`
- Restart during gameplay: Press X on game over screen

### File Management
- **Primary file**: `dollhouse_leak_fixer_compact.p8` (5.5KB, optimized for PICO-8's 8KB limit)
- **Development file**: `dollhouse_leak_fixer.p8` (10KB, readable version with full variable names)
- Use the compact version for actual gameplay, development version for code modifications

### Memory Constraints
- PICO-8 has an 8KB code limit - always check file size with `wc -c *.p8`
- 128x128 pixel display, 16-color palette, 128 8x8 sprites available
- Compress variable names and remove whitespace/comments when approaching limit

## Game Architecture

### Core Systems Overview
The game consists of interconnected systems managing player state, room mechanics, and resource management:

1. **Player System**: Handles movement, room detection, and single-item inventory
2. **Room System**: 5-room dollhouse layout with individual flood states and leak types
3. **Tool System**: Kitchen-based production line cycling through 5 tool types
4. **Flooding System**: Progressive water level mechanics with room lockout
5. **Interaction System**: Tool-leak compatibility matching with visual feedback

### Key Data Structures

**Player Object** (`p` in compact version):
- Position (x,y), dimensions (w,h), current room (r), inventory item (i)

**Room Array** (`rs` in compact version):
- Each room: id, name, position, dimensions, flood_level, leak_state, critical_flag
- Room types: kitchen, bedroom, bathroom, living, attic

**Tool System**:
- 5 tool types with room-specific compatibility rules
- Kitchen cycles tools every 3 seconds (180 frames at 60fps)

### Game Logic Flow

1. **Leak Spawning**: Random timer-based with difficulty scaling (decreasing intervals)
2. **Tool Interaction**: Room-specific compatibility checking prevents incorrect repairs
3. **Flooding Mechanics**: Continuous water level rise when leaks active, attic multiplier affects all rooms
4. **Victory/Defeat**: Survival scoring, game ends when 4 main rooms flood completely

### Tool-Room Compatibility Matrix

- **Bedroom** (ceiling leaks): pot, rag
- **Bathroom** (plumbing): wrench, putty  
- **Living Room** (window cracks): plank, putty
- **Attic** (water tank): wrench, putty
- **Kitchen**: tool source only, no leaks

### Visual Feedback System

The game provides immediate feedback through:
- Color-coded messages (green=success, red=error, white=info)
- Tool requirement hints when wrong tool used
- Flood level bars for each room
- Attic warning indicators when critical leak active

## Code Compression Strategy

When modifying code and approaching the 8KB limit:

1. **Variable Compression**: Long names → 1-2 characters (`gamestate` → `gs`)
2. **Function Compression**: Descriptive names → abbreviations (`update_game` → `ug`)
3. **Property Compression**: Object properties → single letters (`flood_level` → `f`)
4. **Whitespace Removal**: Remove comments, extra spaces, and newlines
5. **Logic Condensation**: Combine similar operations, use ternary operators

## Development Workflow

1. **Modify readable version** (`dollhouse_leak_fixer.p8`) for development
2. **Test functionality** thoroughly in readable format
3. **Create compressed version** when ready for deployment
4. **Verify size constraints** before final PICO-8 loading
5. **Update both versions** to maintain code synchronization

## Game Design Reference

The complete game design document is available in `game_design_doc_with_sketch.pdf` and implementation details in `development_plan.md`. The game follows the original design requirements for:
- Endless survival gameplay
- Room-specific leak scenarios  
- Progressive difficulty scaling
- Retro ZX Spectrum aesthetic
- Simple but engaging mechanics