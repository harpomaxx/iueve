pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- dollhouse leak fixer
-- a retro-inspired leak fixing game
-- player fixes water leaks across 5 rooms using appropriate tools

-- screen and room dimensions
local screen_w = 128  -- pico-8 screen width
local screen_h = 128  -- pico-8 screen height
local room_w = 32     -- standard room width
local room_h = 24     -- standard room height

-- game state variables
local gamestate = "start"     -- current game state: "start", "playing" or "gameover"
local score = 0               -- player score based on survival time + leak fixes
local time_elapsed = 0        -- total frames elapsed since game start
local feedback_msg = ""       -- current message to display to player
local feedback_timer = 0      -- frames remaining to show feedback message

-- player character data
local player = {
  x = 56,           -- x position on screen (start on ladder, adjusted for 16x16)
  y = 103,          -- y position on screen (start at ground floor level, adjusted for 16px height)
  w = 16,           -- player sprite width (16x16 for animation support)
  h = 16,           -- player sprite height
  room = 0,         -- current room id (0=ladder, 1-5=rooms)
  inventory = nil,  -- currently held tool ID (1-5) or nil
  
  -- movement system
  vel_x = 0,        -- horizontal velocity for smooth movement
  max_speed = 1.5,  -- maximum walking speed
  accel = 0.3,      -- acceleration when starting to move
  friction = 0.7,   -- deceleration when stopping
  
  -- animation system
  anim_state = "idle",      -- idle, walking_left, walking_right
  anim_frame = 1,           -- current animation frame (1 or 2)
  anim_timer = 0,           -- frame timing counter
  anim_speed = 15,          -- frames per animation frame (15 = ~4fps at 60fps)
  last_direction = "right"  -- remember last direction for idle pose
}

-- room definitions for the 3-story dollhouse layout (expanded height)
-- ground floor: kitchen + bedroom, second floor: bathroom + living, attic: critical room
local rooms = {
  {id=1, name="kitchen", x=1, y=86, w=48, h=32, flood_level=0, leak=false},     -- ground left: tool pickup
  {id=2, name="bedroom", x=66, y=86, w=59, h=32, flood_level=0, leak=false},    -- ground right: ceiling leaks
  {id=3, name="bathroom", x=1, y=54, w=53, h=32, flood_level=0, leak=false},    -- second left: plumbing leaks
  {id=4, name="living", x=66, y=54, w=59, h=32, flood_level=0, leak=false},     -- second right: window cracks
  {id=5, name="attic", x=1, y=23, w=125, h=32, flood_level=0, leak=false, critical=true}  -- top: water tank leaks
}

-- ladder area for vertical movement between floors (collision area wider than visual)
local ladder = {x=48, y=52, w=18, h=67}

-- floor levels for realistic dollhouse physics (adjusted for 16px player height)
local floor_levels = {
  ground = 103,    -- bottom of ground floor rooms (y=88+32-16 for player height)
  second = 72,     -- bottom of second floor rooms (y=56+32-16 for player height)  
  attic = 40       -- bottom of attic room (y=24+32-16 for player height)
}

-- tool system - kitchen cycles through available tools (numeric IDs save memory)
-- tool IDs: 1=pot, 2=putty, 3=wrench, 4=rag, 5=plank (sprites 32-36)
local current_kitchen_tool = 1      -- index of currently available tool in kitchen
local tool_cycle_timer = 0          -- frames since last tool cycle
local tool_cycle_interval = 120     -- cycle every 2 seconds (120 frames at 60fps)

-- leak spawning system - difficulty increases over time
local leak_timer = 0           -- frames since last leak spawn
local leak_interval = 600      -- initial spawn interval: 10 seconds (decreases over time)
local attic_multiplier = 1     -- flood rate multiplier (2x when attic has leak)

-- flood mechanics - water rises continuously when leaks are active
local flood_rate = 0.004        -- base flood rate per frame (slower for ladder navigation)
local max_flood_level = 25      -- room is completely flooded at this level (adjusted for taller rooms)

-- ========================================
-- PICO-8 CALLBACK FUNCTIONS
-- ========================================

function _init()
  -- reset all game state variables for fresh start
  gamestate = "start"
  score = 0
  time_elapsed = 0
  feedback_msg = ""
  feedback_timer = 0
  
  -- reset player to starting position
  player.x = 56
  player.y = 103
  player.room = 0
  player.inventory = nil
  player.vel_x = 0
  player.anim_state = "idle"
  player.anim_frame = 1
  player.anim_timer = 0
  player.last_direction = "right"
  
  -- reset all room states
  for i, room in pairs(rooms) do
    room.flood_level = 0
    room.leak = false
  end
  
  -- reset tool system
  current_kitchen_tool = nil  -- start with no tool, will generate one immediately
  tool_cycle_timer = 0
  
  -- reset leak spawning system
  leak_timer = 0
  leak_interval = 600  -- reset to initial 10 second interval
  attic_multiplier = 1
  
  -- spawn first leak to start the game
  spawn_random_leak()
end

function _update60()
  -- main update loop called 60 times per second
  if gamestate == "start" then
    update_startscreen()
  elseif gamestate == "playing" then
    update_game()
  elseif gamestate == "gameover" then
    update_gameover()
  end
end

-- ========================================
-- GAME UPDATE FUNCTIONS
-- ========================================

function update_startscreen()
  -- handle input on start screen
  time_elapsed += 1  -- needed for blinking cursor animation
  
  if btnp(4) then  -- x button to start game
    -- initialize game when starting from start screen
    gamestate = "playing"
    score = 0
    time_elapsed = 0
    feedback_msg = ""
    feedback_timer = 0
    
    -- reset player to starting position
    player.x = 56
    player.y = 103
    player.room = 0
    player.inventory = nil
    player.vel_x = 0
    player.anim_state = "idle"
    player.anim_frame = 1
    player.anim_timer = 0
    player.last_direction = "right"
    
    -- reset all room states
    for i, room in pairs(rooms) do
      room.flood_level = 0
      room.leak = false
    end
    
    -- reset tool system
    current_kitchen_tool = nil  -- start with no tool, will generate one immediately
    tool_cycle_timer = 0
    
    -- reset leak spawning system
    leak_timer = 0
    leak_interval = 600  -- reset to initial 10 second interval
    attic_multiplier = 1
    
    -- spawn first leak to start the game
    spawn_random_leak()
  end
end

function update_game()
  -- update all game timers
  time_elapsed += 1
  score = flr(time_elapsed / 60)  -- score = seconds survived
  tool_cycle_timer += 1
  leak_timer += 1
  
  -- countdown feedback message display timer
  if feedback_timer > 0 then
    feedback_timer -= 1
  end
  
  -- cycle to next kitchen tool when timer expires
  if tool_cycle_timer >= tool_cycle_interval then
    if current_kitchen_tool then
      current_kitchen_tool = (current_kitchen_tool % 5) + 1  -- cycle through 5 tools
    else
      current_kitchen_tool = flr(rnd(5)) + 1  -- generate random tool when none available
    end
    tool_cycle_timer = 0
  end
  
  -- spawn new leaks at increasing frequency (difficulty scaling)
  if leak_timer >= leak_interval then
    spawn_random_leak()
    leak_timer = 0
    -- make leaks spawn faster over time (minimum 2 seconds)
    leak_interval = max(120, leak_interval - 5)
  end
  
  -- update all game systems
  update_player()
  update_flooding()
  check_game_over()
end

function update_player()
  -- handle player input and movement with floor-based physics
  local old_x, old_y = player.x, player.y
  
  -- check if player is on ladder for vertical movement
  local on_ladder = player.x >= ladder.x and player.x < ladder.x + ladder.w
  
  -- horizontal movement with smooth acceleration/deceleration
  local moving_horizontal = false
  local moving_vertical = false
  
  if btn(0) then 
    -- accelerate left
    player.vel_x = max(-player.max_speed, player.vel_x - player.accel)
    player.anim_state = "walking_left"
    player.last_direction = "left"
    moving_horizontal = true
  elseif btn(1) then 
    -- accelerate right  
    player.vel_x = min(player.max_speed, player.vel_x + player.accel)
    player.anim_state = "walking_right"
    player.last_direction = "right"
    moving_horizontal = true
  else
    -- apply friction when no input
    if abs(player.vel_x) > 0.1 then
      player.vel_x *= player.friction
    else
      player.vel_x = 0
    end
  end
  
  -- apply velocity to position
  player.x += player.vel_x
  
  -- update horizontal movement state
  if abs(player.vel_x) > 0.1 then
    moving_horizontal = true
    if player.vel_x < 0 then
      player.anim_state = "walking_left"
    else
      player.anim_state = "walking_right" 
    end
  end
  
  -- vertical movement (ONLY on ladder)
  if on_ladder then
    if btn(2) then 
      player.y -= 1
      player.anim_state = "climbing_up"
      moving_vertical = true
    end
    if btn(3) then 
      player.y += 1
      player.anim_state = "climbing_down"
      moving_vertical = true
    end
    
    -- if on ladder but not moving vertically, show ladder idle pose
    if not moving_vertical and not moving_horizontal then
      player.anim_state = "ladder_idle"
    end
  end
  
  -- set idle state when not moving at all
  if not moving_horizontal and not moving_vertical then
    player.anim_state = "idle"
  end
  
  -- apply gravity and floor physics
  apply_floor_physics()
  
  -- constrain player position to valid areas
  constrain_player_position()
  
  -- determine which room player is currently in
  update_player_room()
  
  -- handle interaction input (x button to pick up tools/fix leaks)
  if btnp(4) then
    interact()
  end
  
  -- update animation system
  update_player_animation()
end

function apply_floor_physics()
  -- gravity system: snap player to appropriate floor level based on position
  local on_ladder = player.x >= ladder.x and player.x < ladder.x + ladder.w
  
  -- if not on ladder, apply floor gravity based on room position
  if not on_ladder then
    local target_floor = get_floor_level(player.x, player.y)
    if target_floor then
      player.y = target_floor  -- snap to floor
    end
  end
end

function get_floor_level(x, y)
  -- determine which floor level the player should be on based on position
  -- check ground floor rooms first
  if (x < 48 or x >= 66) and y >= 88 then
    return floor_levels.ground
  -- check second floor rooms  
  elseif (x < 48 or x >= 66) and y >= 56 and y < 88 then
    return floor_levels.second
  -- check attic
  elseif y >= 24 and y < 56 then
    return floor_levels.attic
  end
  return nil  -- on ladder or invalid area
end

function constrain_player_position()
  -- constrain player to valid areas (rooms or ladder)
  player.x = mid(1, player.x, screen_w - player.w)
  player.y = mid(24, player.y, 120 - player.h)  -- expanded house height
  
  -- if not on ladder, must be in a valid room at floor level
  local on_ladder = player.x >= ladder.x and player.x < ladder.x + ladder.w
  if not on_ladder then
    local in_valid_room = false
    
    -- check if player is in any room's horizontal bounds
    for i, room in pairs(rooms) do
      if player.x >= room.x and player.x < room.x + room.w then
        -- check if player is at appropriate floor level for this room
        local correct_floor = get_floor_level(player.x, room.y + room.h/2)
        if correct_floor and player.y == correct_floor then
          in_valid_room = true
          break
        end
      end
    end
    
    -- if not in valid room at floor level, push back to ladder center
    if not in_valid_room then
      player.x = ladder.x + ladder.w/2 - player.w/2  -- center player on ladder
    end
  end
end

function update_player_room()
  -- check collision with each room to determine current location
  for i, room in pairs(rooms) do
    if player.x >= room.x and player.x < room.x + room.w and
       player.y >= room.y and player.y < room.y + room.h then
      player.room = room.id
      return
    end
  end
  -- if not in any room, player is on ladder (room 0 for ladder area)
  player.room = 0
end

-- ========================================
-- INTERACTION SYSTEM
-- ========================================

function interact()
  -- can't interact while on ladder
  if player.room == 0 then
    return
  end
  
  local room = rooms[player.room]
  
  -- kitchen: pick up currently available tool or swap current tool
  if room.name == "kitchen" and current_kitchen_tool then
    if not player.inventory then
      -- pick up tool when not carrying anything
      player.inventory = current_kitchen_tool
      current_kitchen_tool = nil  -- remove tool from kitchen (will regenerate after cycle interval)
      feedback_msg = "picked up tool"
      feedback_timer = 120  -- show message for 2 seconds
      sfx(0)  -- play pickup sound
    else
      -- swap current tool with kitchen tool
      player.inventory = current_kitchen_tool
      current_kitchen_tool = nil  -- remove tool from kitchen (will regenerate after cycle interval)
      feedback_msg = "swapped tool"
      feedback_timer = 120  -- show message for 2 seconds
      sfx(0)  -- play pickup sound
    end
  
  -- other rooms: attempt to fix leak from floor position
  elseif room.leak and player.inventory then
    if can_reach_ceiling_leak(room) and can_fix_leak(room, player.inventory) then
      -- correct tool and in range: fix the leak
      fix_leak(room, player.inventory)
      feedback_msg = "leak fixed!"
      feedback_timer = 120
      player.inventory = nil  -- consume the tool
      sfx(1)  -- play success sound
    elseif not can_reach_ceiling_leak(room) then
      -- not in range of ceiling leak
      feedback_msg = "move closer to leak"
      feedback_timer = 120
      sfx(2)  -- play error sound
    else
      -- wrong tool: show what tools are needed
      feedback_msg = "wrong tool! need: " .. get_correct_tools(room)
      feedback_timer = 180  -- show error message longer
      sfx(2)  -- play error sound
    end
  end
end

function can_reach_ceiling_leak(room)
  -- check if player is close enough to interact with ceiling leak from floor (adjusted for 16x16 player)
  local room_center_x = room.x + room.w / 2
  local player_center_x = player.x + player.w/2
  local distance = abs(player_center_x - room_center_x)
  
  -- player must be within reasonable horizontal distance of leak center (larger range for bigger player)
  return distance <= 20  -- within 20 pixels of room center (was 16)
end

function can_fix_leak(room, tool_id)
  -- check if the given tool ID can fix leaks in the given room
  -- tool IDs: 1=pot, 2=putty, 3=wrench, 4=rag, 5=plank
  if room.name == "bedroom" then
    return tool_id == 1 or tool_id == 4      -- pot or rag: ceiling leaks
  elseif room.name == "bathroom" then
    return tool_id == 3 or tool_id == 2      -- wrench or putty: plumbing leaks
  elseif room.name == "living" then
    return tool_id == 5 or tool_id == 2      -- plank or putty: window cracks
  elseif room.name == "attic" then
    return tool_id == 3 or tool_id == 2      -- wrench or putty: water tank leaks
  end
  return false
end

function get_correct_tools(room)
  -- return string listing which tools work for this room's leaks
  if room.name == "bedroom" then
    return "pot/rag"       -- ceiling leak solutions
  elseif room.name == "bathroom" then
    return "wrench/putty"  -- plumbing leak solutions  
  elseif room.name == "living" then
    return "plank/putty"   -- window crack solutions
  elseif room.name == "attic" then
    return "wrench/putty"  -- water tank leak solutions
  end
  return "wrong tool"
end

function fix_leak(room, tool)
  -- successfully repair a leak and provide flood relief
  room.leak = false  -- stop the leak
  room.flood_level = max(0, room.flood_level - 5)  -- drain some water
  
  -- fixing attic leak removes flood rate multiplier for all rooms
  if room.name == "attic" then
    attic_multiplier = 1  -- reset from 2x back to normal rate
  end
  
  score += 10  -- award bonus points for successful repair
end

-- ========================================
-- LEAK AND FLOODING MECHANICS
-- ========================================

function spawn_random_leak()
  -- randomly spawn a new leak in an available room
  local available_rooms = {}
  
  -- collect rooms that can receive new leaks (exclude kitchen, not already leaking, not fully flooded)
  for i, room in pairs(rooms) do
    if room.name != "kitchen" and not room.leak and room.flood_level < max_flood_level then
      add(available_rooms, room)
    end
  end
  
  -- spawn leak in random available room
  if #available_rooms > 0 then
    local room = available_rooms[flr(rnd(#available_rooms)) + 1]
    room.leak = true
    
    -- attic leaks cause accelerated flooding in all rooms
    if room.name == "attic" then
      attic_multiplier = 2  -- double flood rate everywhere
    end
  end
end

function update_flooding()
  -- increase water level in all rooms with active leaks
  for i, room in pairs(rooms) do
    if room.leak then
      -- flood rate affected by attic multiplier (2x when attic leaks)
      room.flood_level += flood_rate * attic_multiplier
      room.flood_level = min(room.flood_level, max_flood_level)
    end
  end
end

function check_game_over()
  -- count how many rooms are completely flooded (excluding kitchen)
  local flooded_rooms = 0
  for i, room in pairs(rooms) do
    -- kitchen doesn't count toward game over (tool source only), but attic does
    if room.name != "kitchen" and room.flood_level >= max_flood_level then
      flooded_rooms += 1
    end
  end
  
  -- game over when all 4 main rooms are fully flooded (bedroom, bathroom, living, attic)
  if flooded_rooms >= 4 then
    gamestate = "gameover"
  end
end

function update_gameover()
  -- wait for player to restart the game
  if btnp(4) then  -- x button to restart
    _init()
    gamestate = "playing"
  end
end

-- ========================================
-- RENDERING FUNCTIONS
-- ========================================

function _draw()
  -- main render function called once per frame
  cls()  -- clear screen
  
  if gamestate == "start" then
    draw_startscreen()
  elseif gamestate == "playing" then
    draw_game()
  elseif gamestate == "gameover" then
    draw_gameover()
  end
end

function draw_game()
  -- render all game elements for main gameplay
  draw_house()    -- dollhouse layout and room labels
  draw_leaks()    -- leak indicators and attic warnings
  draw_flooding() -- water levels in each room
  
  -- render player character as 2x2 sprite composition
  draw_player()
  
  draw_hud()      -- score, inventory, messages, flood bars
end

function draw_house()
  -- draw 3-story dollhouse cutaway view with central ladder (expanded height)
  
  -- outer house outline (taller house)
  rect(0, 24, 127, 119, 10)
  
  -- floor divisions
  line(0, 56, 127, 56, 10)   -- second floor
  line(0, 88, 127, 88, 10)   -- ground floor
  
  -- vertical room dividers (skip ladder area)
  -- line(48, 56, 48, 119, 10)   -- left rooms | ladder
  -- line(64, 56, 64, 119, 10)   -- ladder | right rooms
  
  -- central ladder (extended)
  for i = 52, 116, 6 do
    line(ladder.x + 8, i, ladder.x + 16, i, 10)  -- ladder rungs
  end
  line(ladder.x + 8, 52, ladder.x + 8, 119, 10)   -- left rail
  line(ladder.x + 16, 52, ladder.x + 16, 119, 10) -- right rail
  
  -- room identification labels (adjusted for taller rooms)
  print("kit", 4, 98, 6)      -- kitchen (ground left)
  print("bed", 84, 98, 6)     -- bedroom (ground right)
  print("bath", 4, 66, 6)     -- bathroom (second left)
  print("liv", 84, 66, 6)     -- living (second right)
  print("attic", 52, 34, 6)   -- attic (top)
  
  -- kitchen tool production display (moved down for taller room)
  print("tool:", 4, 104, 7)
  -- draw current tool sprite instead of text (sprites 32-36 for tools)
  if current_kitchen_tool then
    spr(31 + current_kitchen_tool, 24, 102)
  else
    print("--", 24, 104, 5)  -- show placeholder when no tool available
  end
end

function update_player_animation()
  -- update animation timer
  player.anim_timer += 1
  
  -- different animation speeds for different states
  local current_speed = player.anim_speed
  if player.anim_state == "climbing_up" or player.anim_state == "climbing_down" then
    current_speed = 10  -- faster animation for climbing (more responsive)
  elseif player.anim_state == "ladder_idle" then
    current_speed = 45  -- slower subtle animation when idle on ladder
  elseif player.anim_state == "walking_left" or player.anim_state == "walking_right" then
    -- walking animation speed based on movement velocity for realistic timing
    local speed_factor = abs(player.vel_x) / player.max_speed
    current_speed = max(6, flr(12 - (speed_factor * 4)))  -- faster animation when moving faster
  end
  
  -- switch animation frame when timer reaches speed threshold
  if player.anim_timer >= current_speed then
    player.anim_timer = 0
    if player.anim_frame == 1 then
      player.anim_frame = 2
    else
      player.anim_frame = 1
    end
  end
end

function get_player_sprites()
  -- return sprite IDs based on current animation state and frame
  local tl, tr, bl, br
  
  if player.anim_state == "walking_right" then
    if player.anim_frame == 1 then
      tl, tr, bl, br = 0, 1, 16, 17    -- walking right frame 1
    else
      tl, tr, bl, br = 2, 3, 18, 19    -- walking right frame 2
    end
  elseif player.anim_state == "walking_left" then
    if player.anim_frame == 1 then
      tl, tr, bl, br = 6, 7, 22, 23    -- walking left frame 1
    else
      tl, tr, bl, br = 8, 9, 24, 25    -- walking left frame 2
    end
  elseif player.anim_state == "climbing_up" then
    if player.anim_frame == 1 then
      tl, tr, bl, br = 10, 11, 26, 27   -- climbing up frame 1
    else
      tl, tr, bl, br = 12, 13, 28, 29   -- climbing up frame 2
    end
  elseif player.anim_state == "climbing_down" then
    -- reverse animation frames for climbing down
    if player.anim_frame == 1 then
      tl, tr, bl, br = 12, 13, 28, 29   -- climbing down frame 1 (reversed)
    else
      tl, tr, bl, br = 10, 11, 26, 27   -- climbing down frame 2 (reversed)
    end
  elseif player.anim_state == "ladder_idle" then
    -- static pose when on ladder but not moving
    tl, tr, bl, br = 11, 10, 27, 26   -- holding ladder pose (mirrored climbing frame)
  else
    -- idle state: use frame 1 of last direction
    if player.last_direction == "right" then
      tl, tr, bl, br = 0, 1, 16, 17    -- idle facing right
    else
      tl, tr, bl, br = 4, 5, 20, 21    -- idle facing left
    end
  end
  
  return tl, tr, bl, br
end

function draw_player()
  -- draw 16x16 player using 2x2 sprite composition with animation
  local tl, tr, bl, br = get_player_sprites()
  
  -- add movement effects for different animation states
  local offset_x = 0
  local offset_y = 0
  
  if player.anim_state == "climbing_up" or player.anim_state == "climbing_down" then
    -- subtle sway effect during climbing
    offset_x = player.anim_frame == 1 and -1 or 1
  elseif player.anim_state == "ladder_idle" then
    -- very subtle breathing effect when idle on ladder
    offset_x = flr(sin(time_elapsed / 60) * 0.5)
  elseif player.anim_state == "walking_left" or player.anim_state == "walking_right" then
    -- subtle vertical bob during walking (bouncing effect)
    offset_y = player.anim_frame == 2 and -1 or 0  -- slight hop on frame 2
    -- tiny horizontal shake for more dynamic walking
    offset_x = player.anim_frame == 1 and 0 or (player.anim_state == "walking_right" and 1 or -1)
  end
  
  local draw_x = player.x + offset_x
  local draw_y = player.y + offset_y
  
  spr(tl, draw_x, draw_y)           -- top-left
  spr(tr, draw_x + 8, draw_y)       -- top-right
  spr(bl, draw_x, draw_y + 8)       -- bottom-left
  spr(br, draw_x + 8, draw_y + 8)   -- bottom-right
end

function draw_leaks()
  -- show active leak locations with visual indicators
  for i, room in pairs(rooms) do
    if room.leak then
      -- blue circle indicator for active leak
      circfill(room.x + room.w/2, room.y + 4, 2, 12)
      
      -- special blinking warning for critical attic leaks
      if room.name == "attic" then
        if time_elapsed % 30 < 15 then  -- blink every half second
          print("!", room.x + room.w/2 - 2, room.y + 10, 8)  -- red exclamation
        end
      end
    end
  end
end

function draw_flooding()
  -- draw rising water levels with animated, layered water effects
  for i, room in pairs(rooms) do
    if room.flood_level > 0 then
      local flood_height = flr(room.flood_level)
      local water_bottom = room.y + room.h - flood_height
      local water_top = room.y + room.h
      
      -- draw main water body in dark blue
      rectfill(room.x, water_bottom, room.x + room.w, water_top, 1)  -- dark blue water
      
      -- add animated wave pattern for surface movement
      if flood_height >= 3 then
        local wave_offset = flr(time_elapsed / 8) % 4  -- slow wave animation
        for x = room.x, room.x + room.w - 1, 4 do
          local wave_y = water_bottom + ((x + wave_offset) % 3)
          if wave_y < water_bottom + 3 then
            pset(x, wave_y, 12)  -- cyan wave dots
            pset(x + 1, wave_y, 12)
          end
        end
      end
      
      -- add cyan surface layer (top portion)
      if flood_height >= 2 then
        local cyan_height = max(1, flr(flood_height * 0.15))
        rectfill(room.x, water_bottom, room.x + room.w, 
                 water_bottom + cyan_height, 12)  -- cyan surface
      end
      
      -- add subtle transparency effect with dithered pattern
      if flood_height >= 4 then
        for y = water_bottom + 2, water_top - 1, 2 do
          for x = room.x, room.x + room.w - 1, 2 do
            if (x + y) % 4 == 0 then
              pset(x, y, 5)  -- dark gray dots for depth
            end
          end
        end
      end
      
      -- add bubble effects for active leaks
      if room.leak and flood_height >= 1 then
        local bubble_time = (time_elapsed + room.id * 30) % 60
        if bubble_time < 20 then
          local bubble_x = room.x + room.w/2 + sin(time_elapsed / 30) * 8
          local bubble_y = water_bottom + bubble_time / 3
          if bubble_y < water_top - 1 then
            pset(bubble_x, bubble_y, 7)  -- white bubble
            pset(bubble_x + 1, bubble_y, 6)  -- light gray shadow
          end
        end
      end
    end
  end
end

function draw_hud()
  -- heads-up display showing game status and player feedback
  
  -- current score (survival time + repair bonuses)
  print("score: " .. score, 2, 2, 7)
  
  -- show currently carried tool as sprite
  if player.inventory then
    print("item:", 45, 2, 11)
    spr(31 + player.inventory, 65, 1)  -- player.inventory is now tool ID (1-5)
  end
  
  -- temporary feedback messages with color coding
  if feedback_timer > 0 then
    local color = 11  -- default white
    if sub(feedback_msg, 1, 5) == "wrong" then
      color = 8  -- red for errors
    elseif sub(feedback_msg, 1, 4) == "leak" then
      color = 11 -- green for success
    end
    print(feedback_msg, 2, 14, color)
  end
  
  -- persistent attic leak warning (critical priority)
  if rooms[5].leak then
    print("attic leak!", 80, 2, 8)
  end
  
  -- flood level progress bars for all game rooms (moved to bottom)
  local bar_index = 0
  for i, room in pairs(rooms) do
    if room.name != "kitchen" then  -- skip kitchen (tool source only), include attic
      local bar_x = 2 + bar_index * 30
      local bar_y = 122  -- moved down for taller house
      bar_index += 1
      -- empty bar outline
      rect(bar_x, bar_y, bar_x + 24, bar_y + 4, 7)
      -- filled portion based on flood level
      if room.flood_level > 0 then
        local fill_width = flr((room.flood_level / max_flood_level) * 24)
        rectfill(bar_x, bar_y, bar_x + fill_width, bar_y + 4, 8)  -- red fill
      end
    end
  end
end

function draw_startscreen()
  -- start screen with title, credits, and winter mega jam info
  cls()  -- clear screen with black background
  
  -- big title using repeated characters to make bigger letters
  print("III U U EEE V V EEE", 18, 10, 10)
  print(" I  U U E   V V E  ", 18, 16, 10)
  print(" I  U U EE  v v EE ", 18, 22, 10)
  print(" I  U U E   V V E  ", 18, 28, 10)
  print("III UUU EEE  V  EEE", 18, 34, 10)
  
  -- subtitle/description
  print("programming: harpo and claude", 0, 62, 6) 
  print("art: lili and luca", 20, 70, 6)  -- light gray
  
  -- credits
  print("created for", 35, 80, 6)      -- light gray
  print("winter mega jam 2025", 20, 88, 11)     -- cyan highlight
  print("mendoza, argentina", 25, 96, 11)       -- cyan highlight
  
  -- start instruction
  print("press x to start", 28, 115, 7)         -- white
  
  -- add a simple blinking cursor effect
  if time_elapsed % 60 < 30 then  -- blink every second
    print(">", 20, 115, 7)  -- simple cursor
  end
end

function draw_gameover()
  -- game over screen with final score and restart prompt
  print("game over!", 40, 50, 8)       -- red game over text
  print("final score: " .. score, 35, 60, 7)  -- white score display
  print("press x to restart", 25, 70, 6)      -- gray restart instruction
end

-- ========================================
-- SPRITE AND SOUND DATA
-- ========================================
-- Graphics and audio data defined in __gfx__ and __sfx__ sections below

__gfx__
00000011111100000000001111110000000001111110000000001111110000000000111111000000000001111110000000000111111000000000000000000000
00001111111111000000111111111100000111111111100000111111111100000011111111110000000111111111100000011111111110000000000000000000
00011111111111100001111111111110001111111111110001111111111110000111111111111000001111111111110000111111111111000000000000000000
000111111fff1110000111111fff111000111111111111000111fff1111110000111fff111111000001111111111110000111111111111000000000000000000
00011fffff5ff55000011fffff5ff5500051ffffffff1500055ff5fffff11000055ff5fffff110000051f111111f15000051f111111f15000000000000000000
00011fffff5ff50000011fffff5ff5000001ff5ff5ff1000005ff5fffff11000005ff5fffff110000001ff1111ff10000005ff1111ff50000000000000000000
00001ffffffff50000001ffffffff5000005ff5ff5ff5000005ffffffff10000005ffffffff100000005ffffffff50000555ffffffff55500000000000000000
000015ffffff0000000015ffffff000000055ffffff550000000ffffff5100000000ffffff51000000055ffffff55000f4455ffffff5544f0000000000000000
000005555555000000000555555500000054555555554500000055555550000000005555555000000054555555554500f54455555555445f0000000000000000
00000544544500000000054454450000f54454444445445f00005445445000000000544544500000f54455444455445f00545544445545000000000000000000
00000333544500000000033355445000f44533444433544f00005445333000000005445533300000f44533444433544f00053344443350000000000000000000
00000363554400000000036315544f000555353553535550000044553630000000f4455136300000055535355353555000053535535350000000000000000000
0000005311f300000000005311330000000513333331500000003f11350000000000331135000000000513333331500000001333333100000000000000000000
00000335133500000000053311335000000513333331500000005331533000000005331133500000000513333331500000051333333150000000000000000000
00000335033500000000053300335000000513355331500000005330533000000005330033500000000513355331500000051335533150000000000000000000
00000535053500000000533500535000000533500533500000005350535000000005350053350000000533500533500000053350053350000000000000000000
00000000000000000000000004444440000000000ff0000000000333330000666666000000007770000000000000000000000000000000000000000000000000
0000550000000000000aa00004f4ff40000000000ffff00000033333333306666666660000777777700000000000000000000000000000000000000000000000
000050505500005500a9aa0004f4ff4000000000fffff0000333b333b3306633cc336600777ccc77700000000000000000000000000000000000000000000000
000055505d5555d50aa99a0004ffff4000000000ffff000033333333330666666666007777777770000000000000000000000000000000000000000000000000
000600005dddddd50a999aa004fffff0000000000ff0000000033333300066666600000077770000000000000000000000000000000000000000000000000000
056000005ddddd650a9a99aa04ffff400000000000f0000000003333000006666000000007770000000000000000000000000000000000000000000000000000
00500000056666500a9aa99a04ff4f40000000000000000000000333000006666000000007770000000000000000000000000000000000000000000000000000
00000000005555000aa00aaa044444400000000000000000000000000000aaaaa0aaaaa000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000aaaaa00000aaaaa0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000aaaaa000000000aaaa000000000000000000000000000000000000000000000000000000
000000000000000000000000000cccccccccccccaaaaa0000000000000000000000000000000000000000aaaaa00000000000000000000000000000000000000
000000000000000000000000000cccccccccccccaaa00000000000000000aaaaaaaaaaa0000000000000000aaaaa000000000000000000000000000000000000
000000000000000000000000000ccccccccccccca0000000000000000000aaaaaaaaaaa000000000000000000aaaa00000000000000000000000000000000000
000000000000000000000000000ccccccccccccc00000000000000000000aa0000000aa00000000000000000000aaaa000000000000000000000000000000000
000000000000000000000000000ccccccccccccc00000000000000000000aa0000000aa000000000000000000000aaaaa0000000000000000000000000000000
000000000000000000000000000ccccccccccccc00000000000000000000aa0000000aa00000000000000000000000aaaaa00000000000000000000000000000
000000000000000000000000000ccccccccccccc00000000000000000000aa0000000aa0000000000000000000000000aaaa0000000000000000000000000000
000000000000000000000000000ccccccccccccc00000000000000000000aa0000000aa000000000000000000000000000aaaa00000000000000000000000000
00000000000000000aaeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888888888888888888888aa000000000000000
00000000000000000aaeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888888888888888888888aa000000000000000
00000000000000000aaeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888888888888888888888aa000000000000000
00000000000000000aaeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888888888888888888888aa000000000000000
00000000000000000aaeeeeee000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaaaaaaaaaaa8888888888888888888888aaaaaaaaa888888888aa000000000000000
00000000000000000aaeeeee0ccc0eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888aaaaaaaaa888888888aa000000000000000
00000000000000000aaeeee0c676c0eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888aa00000aa888888888aa000000000000000
00000000000000000aaeee0c67666c0eeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa0000000aa8888888888888888888888aa00000aa888888888aa000000000000000
00000000000000000aaeeeeceeceeeeeeeeeeeeeeeee1e1e0eeeeeeeeeeeaa0000000aa88888111bb11188888888888888888888880cc08aa000000000000000
00000000000000000aaee0660707060eeeeeeeeeeeeee1ee6eeeeee000eeaa0000000aa88888881b718888888888888888888888880cc08aa000000000000000
00000000000000000aaeee0c67767c0eeeeeeeeeeeeeeeeeceeeeee060eeaa0000000aa88888111bb11188888888888888888888880cc08aa000000000000000
00000000000000000aaeee0cc7c7c0100000000000000000ceeeeee010eeaa0000000aa888881bb7bbb1888888888888888888876700c08aa000000000000000
00000000000000000aaeeee0cc6c1ce061616601616166100e00000060eeaaaaaaaaaaa8811111111111118000088888888888777670c08aa000000000000000
00000000000000000aaeeeee01110ee0016cccccccccc710ee06166161eeaa0000000aa8819aaaaaaaaa9180cc088888888887767700c08aa000000000000000
00000000000000000aaeeeee01610eee0167cccccccc7c10ee00706110eeaa0000000aa881aaaaaaaaaaa180cc00000000000000000cc08aa000000000000000
00000000000000000aaeeeee01610eee01167cccccc7c100eee1166c10eeaa0000000aa881aa1aaaaa1aa180c6ccccccccccccccccc6c08aa000000000000000
00000000000000000aa00000000000000000000000000000000000000000aa0000000aa0000000000000000000000000000000000000000aa000000000000000
00000000000000000aa00000000000000000000000000000000000000000aa0000000aa0000000000000000000000000000000000000000aa000000000000000
00000000000000000aa00000000000000000000000000000000000000000aa0000000aa0000000000009999999999999999999000000000aa000000000000000
00000000000000000aa00000000000000000000000000000000000000000aaaaaaaaaaa0000000000009ccccccccccccccc3c9000000000aa000000000000000
00000000000000000aa00000000000000009999999999999999999999000aa0000000aa0000000000009cccc3ccccccccc3b39000000000aa000000000000000
00000000000000000aa00000000000000009000000000900000000009000aa0000000aa0000000000009ccc3b3cccccccc93b9000000000aa000000000000000
00000000000000000aa00000000000000009000000000900000000009000aa0000000aa0000000000009cc34343ccccc3b3939000000000aa000000000000000
00000000000000000aa00000000000000009000000000900000000009000aa0000000aa0000000000009c3b39343cccbb343b9000000000aa000000000000000
00000000000000000aa2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2aa0000000aa0000088888000000000000000000000000000000aa000000000000000
00000000000000000aae2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2eaa0000000aa0000088888000000000000333333330000000000aa000000000000000
00000000000000000aa2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2aa0000000aa0000088888000000000003333333333000000000aa000000000000000
00000000000000000aa99999999999999999999999999900000000000000aaaaaaaaaaa00999999999999900000333b3333b33300000000aa000000000000000
00000000000000000aa0000000009cccccc9cccc9cccc900000000000000aa0000000aa0009ffff9ffff900000033333333333300000000aa000000000000000
00000000000000000aa09090909099999999999999999900000000000000aa0000000aa0009ffff9ffff9000000333b3333b33300000000aa000000000000000
00000000000000000aa0000000009bbbbbb9333393333900000000000000aa0000000aa0009999999999900000033333333333300000000aa000000000000000
00000000000000000aa9999999999bbbbbb9333393333900000000000000aa0000000aa0009000000000900000000333333330000000000aa000000000000000
000000000000000000000000000000000000000000000000000000000000aa0000000aa000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000aa0000000aa000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000aa0000000aa000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000aa0000000aa000000000000000000000000000000000000000000000000000000000
__sfx__
001000000c0500e0500f0501005012050140501505016050180501a0501b0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c05000000000000000000000000000000000000
001000001005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005000000
00100000060500a0500e0501105013050140501505016050170501805019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905000000
