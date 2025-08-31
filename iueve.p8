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
local gamestate = "start"     -- current game state: "start", "cinematic", "playing" or "gameover"
local score = 0               -- player score based on survival time + leak fixes
local highscore = 0           -- persistent high score
local new_highscore = false   -- flag for new high score achievement
local time_elapsed = 0        -- total frames elapsed since game start
local feedback_msg = ""       -- current message to display to player
local feedback_timer = 0      -- frames remaining to show feedback message

-- cinematic variables
local cinematic_time = 0      -- frames elapsed in cinematic
local cinematic_phase = 1     -- current phase of cinematic (1=rain, 2=text)
local rain_drops = {}         -- array of rain drop positions

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

-- music system - background music state
local current_music = -1       -- currently playing music track (-1 = none)
local music_enabled = true     -- allow music on/off toggle

-- ========================================
-- CINEMATIC HELPER FUNCTIONS
-- ========================================

function init_rain_drops()
  rain_drops = {}
  for i = 1, 50 do
    add(rain_drops, {
      x = rnd(128),
      y = rnd(128),
      speed = 2 + rnd(3),
      len = 3 + rnd(2)
    })
  end
end

function update_rain()
  for drop in all(rain_drops) do
    drop.y += drop.speed
    if drop.y > 128 then
      drop.y = -drop.len
      drop.x = rnd(128)
    end
  end
end

function start_actual_game()
  gamestate = "playing"
  score = 0
  time_elapsed = 0
  feedback_msg = ""
  feedback_timer = 0
  
  player.x = 56
  player.y = 103
  player.room = 0
  player.inventory = nil
  player.vel_x = 0
  player.anim_state = "idle"
  player.anim_frame = 1
  player.anim_timer = 0
  player.last_direction = "right"
  
  for i, room in pairs(rooms) do
    room.flood_level = 0
    room.leak = false
  end
  
  current_kitchen_tool = nil
  tool_cycle_timer = 0
  leak_timer = 0
  leak_interval = 600
  attic_multiplier = 1
  
  spawn_random_leak()
  
  if music_enabled and current_music != 1 then
    play_music(1)
  end
end

-- ========================================
-- PICO-8 CALLBACK FUNCTIONS
-- ========================================

function _init()
  -- initialize persistent data storage
  cartdata("iueve_dollhouse")
  
  -- reset all game state variables for fresh start
  gamestate = "start"
  score = 0
  highscore = dget(0)  -- load persistent high score
  new_highscore = false
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
  
  -- reset music state
  current_music = -1
  if music_enabled then
    play_music(0)  -- start with title music
  end
end

function _update60()
  -- main update loop called 60 times per second
  if gamestate == "start" then
    update_startscreen()
  elseif gamestate == "cinematic" then
    update_cinematic()
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
  
  -- toggle music with O button
  if btnp(5) then
    toggle_music()
    sfx(0)  -- play confirmation sound
  end
  
  if btnp(4) then  -- x button to start game
    -- start cinematic sequence
    gamestate = "cinematic"
    cinematic_time = 0
    cinematic_phase = 1
    init_rain_drops()
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
    
    -- play atmospheric rain sound
    if music_enabled then
      sfx(12)  -- rain sound effect
    end
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
  
  -- check if player is on ladder for Y constraints
  local on_ladder = player.x >= ladder.x and player.x < ladder.x + ladder.w
  
  if on_ladder then
    -- when on ladder, allow reaching attic floor (y=40) but prevent climbing too high above ladder
    player.y = mid(floor_levels.attic, player.y, ladder.y + ladder.h - player.h)
  else
    -- when not on ladder, constrain to full house height
    player.y = mid(24, player.y, 120 - player.h)  -- expanded house height
  end
  
  -- if not on ladder, must be in a valid room at floor level
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
      sfx(10)  -- dramatic attic leak sound
    else
      sfx(9)  -- regular leak spawn sound
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
    
    -- check for new high score
    if score > highscore then
      highscore = score
      new_highscore = true
      dset(0, highscore)  -- save new high score to persistent memory
    end
    
    -- play game over music
    if music_enabled and current_music != 2 then
      play_music(2)  -- sad game over music
    end
  end
end

function update_gameover()
  -- wait for player to restart the game
  if btnp(4) then  -- x button to restart
    new_highscore = false  -- reset new high score flag
    _init()
    gamestate = "playing"
  end
end

-- ========================================
-- MUSIC SYSTEM FUNCTIONS
-- ========================================

function play_music(track)
  -- switch to a new background music track
  if music_enabled and track != current_music then
    music(track)  -- start playing the music track
    current_music = track
  end
end

function stop_music()
  -- stop all background music
  music(-1)
  current_music = -1
end

function toggle_music()
  -- toggle music on/off
  music_enabled = not music_enabled
  if not music_enabled then
    stop_music()
  else
    -- resume appropriate music for current game state
    if gamestate == "start" then
      play_music(0)  -- title music
    elseif gamestate == "playing" then
      play_music(1)  -- gameplay music
    elseif gamestate == "gameover" then
      play_music(2)  -- game over music
    end
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
  elseif gamestate == "cinematic" then
    draw_cinematic()
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
 -- print("kit", 4, 98, 6)      -- kitchen (ground left)
 -- print("bed", 84, 98, 6)     -- bedroom (ground right)
 -- print("bath", 4, 66, 6)     -- bathroom (second left)
 -- print("liv", 84, 66, 6)     -- living (second right)
 -- print("attic", 52, 34, 6)   -- attic (top)
  
  -- kitchen tool production display (moved down for taller room)
  print("tool:", 4, 104, 7)
  -- draw current tool sprite instead of text (sprites 32-36 for tools)
  if current_kitchen_tool then
    spr(31 + current_kitchen_tool,10, 110)
  else
    print("--", 10, 110, 5)  -- show placeholder when no tool available
  end
  draw_32x32_sprite(48,23,87)
  draw_32x32_sprite(52,83,87)
  draw_32x32_sprite(56,83,58)
  draw_32x32_sprite(128,10,65)
  spr(92,2,38)
  spr(93,10,38)
  spr(108,2,47)
  spr(109,10,47)
  spr(149,70,48)
  spr(148,78,48)
  spr(148,75,40)
  spr(132,10,91)
end

function draw_32x32_sprite(sprite_id, x, y)
    -- draw 4x4 grid of 8x8 sprites
    for dy = 0, 3 do
      for dx = 0, 3 do
        local sid = sprite_id + dx + dy * 16
        spr(sid, x + dx * 8, y + dy * 8)
      end
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
      
      -- play water drop sound occasionally (every 3-4 seconds per leak)
      local drop_interval = 180 + (room.id * 30)  -- offset timing between rooms
      if (time_elapsed + room.id * 45) % drop_interval == 0 then
        sfx(11)  -- water drop sound
      end
      
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
  print("III U U EEE V V EEE", 18, 5, 10)
  print(" I  U U E   V V E  ", 18, 11, 10)
  print(" I  U U EE  v v EE ", 18, 16, 10)
  print(" I  U U E   V V E  ", 18, 23, 10)
  print("III UUU EEE  V  EEE", 18, 29, 10)
  
  -- subtitle/description
  print("programming: harpo and claude", 0, 52, 6) 
  print("art: lili and luca", 20, 60, 6)  -- light gray
  print("design ideas: bruno",20,68,6)
  -- high score display
  print("high score: " .. highscore, 30, 40, 11)  -- cyan highlight
  
  -- credits
  print("created for", 35, 80, 6)      -- light gray
  print("winter mega jam 2025", 20, 88, 11)     -- cyan highlight
  print("mendoza, argentina", 25, 96, 11)       -- cyan highlight
  
  -- start instruction
  print("press button (or Z) to start", 8, 115, 7)         -- white
  
  -- music toggle instruction
  local music_status = music_enabled and "on" or "off"
  print("o: music " .. music_status, 28, 105, 6)  -- gray
  
  -- add a simple blinking cursor effect
  if time_elapsed % 60 < 30 then  -- blink every second
    print(">", 2, 115, 7)  -- simple cursor
  end
end

function draw_gameover()
  -- game over screen with final score and restart prompt
  print("game over!", 40, 50, 8)       -- red game over text
  print("final score: " .. score, 35, 60, 7)  -- white score display
  
  -- show high score achievement or current high score
  if new_highscore then
    print("new high score!", 32, 70, 11)  -- cyan for new achievement
  else
    print("high score: " .. highscore, 32, 70, 6)  -- gray for existing high score
  end
  
  print("press button to restart", 20, 85, 6)      -- gray restart instruction
end

function update_cinematic()
  cinematic_time += 1
  
  if cinematic_phase == 1 then
    update_rain()
    if cinematic_time >= 240 then
      cinematic_phase = 2
      cinematic_time = 0
    end
  elseif cinematic_phase == 2 then
    update_rain()
    if cinematic_time >= 420 then
      start_actual_game()
    end
  end
  
  if btnp(4) or btnp(5) then
    start_actual_game()
  end
end

function draw_cinematic()
  cls(1)
  draw_rain()
  
  if cinematic_phase == 1 then
    if cinematic_time < 60 then
      print("*heavy rain sounds*", 25, 115, 6)
    end
  elseif cinematic_phase == 2 then
    rectfill(5, 45, 123, 95, 1)
    rect(5, 45, 123, 95, 7)
    
    print("ah, mendoza...", 35, 50, 7)
    
    if cinematic_time > 60 then
      print("where houses from the 40s", 18, 58, 11)
    end
    
    if cinematic_time > 120 then
      print("still use the same pipes", 16, 66, 11)
    end
    
    if cinematic_time > 180 then
      print("and every time it rains...", 16, 74, 8)
    end
    
    if cinematic_time > 240 then
      print("brings new adventures!", 18, 82, 12)
    end
    
    if cinematic_time > 300 then
      print("press any button to start", 12, 100, 6)
    end
  end
end

function draw_rain()
  for drop in all(rain_drops) do
    line(drop.x, drop.y, drop.x, drop.y - drop.len, 12)
    
    if drop.speed > 3 then
      pset(drop.x, drop.y - 1, 7)
    end
  end
  
  if rnd() < 0.3 then
    local splash_x = rnd(128)
    pset(splash_x, 127, 12)
    pset(splash_x + 1, 127, 12)
    pset(splash_x - 1, 127, 12)
  end
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
00000000000077700000000000000000044444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000077777700005500000aa00004f4ff400000000000000000000000000000000000000000700000000000000000000000000000000000000000000000
55000055777ccc770000505000a9aa0004f4ff400000000000000000000000000000000000000000700000000000000000000000000000000000000000000000
5d5555d577777770000055500aa99a0004ffff400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5dddddd577770000000600000a999aa004fffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ddddd6507770000056000000a9a99aa04ffff400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0566665007770000005000000a9aa99a04ff4f400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0055550000000000000000000aa00aaa044444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e20000000000000000000000000000000000000000000000000aaaaaaaaa00000000000000000000000000000000000000
2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e0000000000999999999999999999900000000000000000000aaaaaaaaa00000000000000000000000000000000000000
e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e200000000009ccccccccccccccc3c900000000000000000000aa00000aa00000000000000000000000000000000000000
2e2e2e99999999999999999999992e2e00000000009cccc3ccccccccc3b3900000000000000000000aa00000aa00000000000000000000000000000000000000
e2e2e29000000000900000000009e2e200000000009ccc3b3cccccccc93b900000000000000000000aaaaaaaaa00000000000000000000000000000000000000
2e2e2e90000000009000000000092e2e00000000009cc34343ccccc3b393900000000000000000000aaaaaaaaa00000000000000000000000000000000000000
e2e2e29000000000900000000009e2e200000000009c3b39343cccbb343b900000000000000000000a0000000a00000000000000000000000000000000000000
2e2e2e90000000009000000000092e2e00000000009449444444c444bb449000000bb000000000000a0000000a00000000000000000000000000000000000000
e2e2e29000000000900000000009e2e200000b0000944444494444944494900000bb7b00000000000aaaaaaaaa00000000000000000000000000000000000000
2e2e2e90000000009000000000092e2e00000bb000944494444944449449900000bbbb00000000000aaaaaaaaa00000000000000000000000000000000000000
e2e2e29000000000900000000009e2e20000bb0b009cc7ccccc44c7cccc49000007b7bb000000000000000000000000000000000000000000000000000000000
2e2e2e99999999999999999999992e2e000b0b00b09c7ccc7cccccccc7cc90000bbbbb700000000000000000000006c000000000000000000000000000000000
e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e200b00bb0009999999999999999999000000bb000000000000000000000000cc000000cccccc000000000000000000000
2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e00000b0b000000000000000000000000000b7000000000000000000000000cc000000000000000000000000000000000
e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e200000b00b00000000000000000000000000bb000000000000000000000000cc00000cccccccc00000000000000000000
2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e000888880000000000000000000000000bb7bbb00000000000000000076700c0000cccccccccc0000000000000000000
e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e200088888000000000000333333330000000000000000000000000000777670c000000000000000000000000000000000
2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e000888880000000000033333333330009aaaaaaa00cc000000000007767700c0000cccccccccc0000000000000000000
9999999999999999999999999992e2e2999999999999900000333b3333b33300aaaaaaaa00cc00000000000000000cc0000cccccccccc0000000000000000000
0000000009cccccc9cccc9cccc9e2e2e09ffff9ffff900000033333333333300aa1aaa1a00c6ccccccccccccccccc6c0000cccccccccc0000000000000000000
0909090909999999999999999992e2e209ffff9ffff9000000333b3333b33300aaaaaaaa00ccccccccccccccccccccc0000cccccccccc0000000000000000000
0000000009bbbbbb93333933339e2e2e09999999999900000033333333333300aaaaaaaa00ccccccccccccccccccccc0000cccccccccc0000000000000000000
9999999999bbbbbb933339333392e2e209000000000900000000333333330000aaaaaaaa00ccc6ccc6ccccccccc6ccc0000cccccccccc0000000000000000000
8888888889bbbbbb93333933339e2e2e09000000000900003330333333330333aaaaaaaa00cc000000000000000000c0000cccccccccc0000000000000000000
86666bb689bbbbbb933939393392e2e20900000000090000333000000000033399000009006c000000000000000000c0000cccccccccc0000000000000000000
88888bb889bbbbbb93333933339e2e2e090000000009000003303333333303300000000000000000000000000000000000000000000000000000000000000000
88888bb889bbbbbb933339333392e2e20900000000090000033000000000033000000000000000000000000000000000000cccccccccc0000000000000000000
88888bb889bbbbbb93333933339e2e2e09000000000900000333333333333330000000000000000000000000000000000000c000000c00000000000000000000
8888888889bbbbbb933339333392e2e2090000000009000003300000000003300000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000009999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc00000000000000000000000000097777900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c676c0000000000000000000000000977777790000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c67666c00000000000ccc0000000000977077790000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c76667c00000000000c00c000000000977700790000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c66676c00000000000c00c000000000977777790000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c66766c00000000000000c000000000097777900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c67667c00000000007670c000000000009999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c76676c00000000000000c000000000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
0ccccccc0000000000010160000000004ffffff44666666400000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000c00000000049fffff44966666400000000000000000000000000000000000000000000000000000000000000000000000000000000
0ceec000000000000010100000000000499999944999999400000000000000000000000000000000000000000000000000000000000000000000000000000000
0ceec000000000000001006000000000499999944999999400000000000000000000000000000000000000000000000000000000000000000000000000000000
6607070600000000000000c000000000499999944999999400000000000000000000000000000000000000000000000000000000000000000000000000000000
0c67767c00000000000000c0000000604ffffff44666666400000000000000000000000000000000000000000000000000000000000000000000000000000000
0cc7c7c0100000000066100000000010444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000
00cc6c1c061616601616100000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000111000016cccccccccc7106166161000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001610000167cccccccc7c100706110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00016100001167cccccc7c1001166c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001610000016c7cccccc1100006c610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011100000166c7cccc610000061c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011100000111111111100000006610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000c0500e0500f0501005012050140501505016050180501a0501b0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c05000000000000000000000000000000000000
001000001005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005000000
00100000060500a0500e0501105013050140501505016050170501805019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905000000
001000000f0500e0500c0500a05008050060500405002050000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400001605018050190501a0501b0501c0501d0501e0501f0502005021050220502305024050250502605027050280502905029050290502905029050290502905029050290502905029050290502905029050
010400000c0500b0500a0500905008050070500605005050040500305002050010500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050
001000000305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305000000
011000200f0341003410034100341003410034100341003410034100341003410034100341003410034100340f0340f0340f0340f0340f0340f0340f0340f0340f0340f0340f0340f0340f0340f0340f0340f034
011000200c0341003410034100341003410034100341003410034100341003410034100341003410034100340c0340c0340c0340c0340c0340c0340c0340c0340c0340c0340c0340c0340c0340c0340c0340c034
001000001c0501a050180501605014050120501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005000000
001800001805015050120500f0500c050090500605004050020500105000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050
001000001d05000050000400003000e0000e0000e0000e0000e000000000000000001ce1033e701ce200000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000505006050070500805009050090500905009050090500905009050090500905009050090500905009050090500905009050090500905009050090500905009050090500905009050090500905000000
001000000c0500d0500e0500f050100501105012050130501405015050160501705018050190501a0501b0501c0501d0501e0501f050200502105022050230502405025050260502705028050290502a0502b050
001000001f0501e0501d0501c0501b0501a050190501805017050160501505014050130501205011050100500f0500e0500d0500c0500b0500a05009050080500705006050050500405003050020500105000050
__music__
00 03444344
01 05464546
02 07484748

