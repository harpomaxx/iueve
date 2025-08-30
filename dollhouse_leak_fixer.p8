pico-8 cartridge // http://www.pico-8.com
ver 4
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
local gamestate = "playing"   -- current game state: "playing" or "gameover"
local score = 0               -- player score based on survival time + leak fixes
local time_elapsed = 0        -- total frames elapsed since game start
local feedback_msg = ""       -- current message to display to player
local feedback_timer = 0      -- frames remaining to show feedback message

-- player character data
local player = {
  x = 60,           -- x position on screen (start on ladder)
  y = 100,          -- y position on screen (adjusted for taller house)
  w = 8,            -- player sprite width
  h = 8,            -- player sprite height
  sprite = 1,       -- sprite index for drawing
  room = 0,         -- current room id (0=ladder, 1-5=rooms)
  inventory = nil   -- currently held tool (string) or nil
}

-- room definitions for the 3-story dollhouse layout (expanded height)
-- ground floor: kitchen + bedroom, second floor: bathroom + living, attic: critical room
local rooms = {
  {id=1, name="kitchen", x=0, y=88, w=48, h=32, flood_level=0, leak=false},     -- ground left: tool pickup
  {id=2, name="bedroom", x=80, y=88, w=48, h=32, flood_level=0, leak=false},    -- ground right: ceiling leaks
  {id=3, name="bathroom", x=0, y=56, w=48, h=32, flood_level=0, leak=false},    -- second left: plumbing leaks
  {id=4, name="living", x=80, y=56, w=48, h=32, flood_level=0, leak=false},     -- second right: window cracks
  {id=5, name="attic", x=0, y=24, w=128, h=32, flood_level=0, leak=false, critical=true}  -- top: water tank leaks
}

-- ladder area for vertical movement between floors (extended height)
local ladder = {x=48, y=24, w=32, h=96}

-- tool system - kitchen cycles through available tools
local tool_types = {"pot", "putty", "wrench", "rag", "plank"}  -- all available tool types
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
  -- initialize game state and spawn first leak
  spawn_random_leak()
end

function _update60()
  -- main update loop called 60 times per second
  if gamestate == "playing" then
    update_game()
  elseif gamestate == "gameover" then
    update_gameover()
  end
end

-- ========================================
-- GAME UPDATE FUNCTIONS
-- ========================================

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
    current_kitchen_tool = (current_kitchen_tool % #tool_types) + 1
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
  -- handle player input and movement with ladder mechanics
  local old_x, old_y = player.x, player.y
  
  -- check if player is on ladder for vertical movement
  local on_ladder = player.x >= ladder.x and player.x < ladder.x + ladder.w
  
  -- horizontal movement (always allowed)
  if btn(0) then player.x -= 1 end  -- left arrow
  if btn(1) then player.x += 1 end  -- right arrow
  
  -- vertical movement (only on ladder or within same room)
  if btn(2) then  -- up arrow
    if on_ladder or can_move_vertically(player.x, player.y - 1) then
      player.y -= 1
    end
  end
  if btn(3) then  -- down arrow
    if on_ladder or can_move_vertically(player.x, player.y + 1) then
      player.y += 1
    end
  end
  
  -- constrain player position to valid areas
  constrain_player_position()
  
  -- determine which room player is currently in
  update_player_room()
  
  -- handle interaction input (x button to pick up tools/fix leaks)
  if btnp(4) then
    interact()
  end
end

function can_move_vertically(x, new_y)
  -- check if vertical movement is allowed within current room boundaries
  for i, room in pairs(rooms) do
    if x >= room.x and x < room.x + room.w and
       player.y >= room.y and player.y < room.y + room.h then
      -- allow movement within current room's vertical bounds
      return new_y >= room.y and new_y < room.y + room.h
    end
  end
  return false
end

function constrain_player_position()
  -- constrain player to valid areas (rooms or ladder)
  player.x = mid(0, player.x, screen_w - player.w)
  player.y = mid(24, player.y, 120 - player.h)  -- expanded house height
  
  -- if not on ladder, must be in a valid room
  local on_ladder = player.x >= ladder.x and player.x < ladder.x + ladder.w
  if not on_ladder then
    local in_valid_room = false
    for i, room in pairs(rooms) do
      if player.x >= room.x and player.x < room.x + room.w and
         player.y >= room.y and player.y < room.y + room.h then
        in_valid_room = true
        break
      end
    end
    -- if not in valid room, push back to ladder
    if not in_valid_room then
      player.x = ladder.x + ladder.w/2 - player.w/2
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
  if room.name == "kitchen" then
    if not player.inventory then
      -- pick up tool when not carrying anything
      player.inventory = tool_types[current_kitchen_tool]
      feedback_msg = "picked up " .. player.inventory
      feedback_timer = 120  -- show message for 2 seconds
      sfx(0)  -- play pickup sound
    else
      -- swap current tool with kitchen tool
      local old_tool = player.inventory
      player.inventory = tool_types[current_kitchen_tool]
      feedback_msg = "swapped " .. old_tool .. " for " .. player.inventory
      feedback_timer = 120  -- show message for 2 seconds
      sfx(0)  -- play pickup sound
    end
  
  -- other rooms: attempt to fix leak with current tool
  elseif room.leak and player.inventory then
    if can_fix_leak(room, player.inventory) then
      -- correct tool: fix the leak
      fix_leak(room, player.inventory)
      feedback_msg = "leak fixed!"
      feedback_timer = 120
      player.inventory = nil  -- consume the tool
      sfx(1)  -- play success sound
    else
      -- wrong tool: show what tools are needed
      feedback_msg = "wrong tool! need: " .. get_correct_tools(room)
      feedback_timer = 180  -- show error message longer
      sfx(2)  -- play error sound
    end
  end
end

function can_fix_leak(room, tool)
  -- check if the given tool can fix leaks in the given room
  -- each room type has specific tools that work for its leak types
  if room.name == "bedroom" then
    return tool == "pot" or tool == "rag"      -- ceiling leaks: catch or absorb water
  elseif room.name == "bathroom" then
    return tool == "wrench" or tool == "putty"  -- plumbing leaks: tighten or seal pipes
  elseif room.name == "living" then
    return tool == "plank" or tool == "putty"   -- window cracks: board up or seal cracks
  elseif room.name == "attic" then
    return tool == "wrench" or tool == "putty"  -- water tank leaks: repair fittings or seal
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
  return "unknown"
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
  -- count how many main floor rooms are completely flooded
  local flooded_rooms = 0
  for i, room in pairs(rooms) do
    -- only count main floor rooms (attic flooding doesn't end game)
    if room.name != "attic" and room.flood_level >= max_flood_level then
      flooded_rooms += 1
    end
  end
  
  -- game over when all 4 main rooms are fully flooded
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
  
  if gamestate == "playing" then
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
  
  -- render player character sprite
  spr(player.sprite, player.x, player.y)
  
  draw_hud()      -- score, inventory, messages, flood bars
end

function draw_house()
  -- draw 3-story dollhouse cutaway view with central ladder (expanded height)
  
  -- outer house outline (taller house)
  rect(0, 24, 127, 119, 7)
  
  -- floor divisions
  line(0, 56, 127, 56, 7)   -- second floor
  line(0, 88, 127, 88, 7)   -- ground floor
  
  -- vertical room dividers (skip ladder area)
  line(48, 56, 48, 119, 7)   -- left rooms | ladder
  line(80, 56, 80, 119, 7)   -- ladder | right rooms
  
  -- central ladder (extended)
  for i = 28, 116, 4 do
    line(ladder.x + 8, i, ladder.x + 24, i, 6)  -- ladder rungs
  end
  line(ladder.x + 8, 24, ladder.x + 8, 119, 6)   -- left rail
  line(ladder.x + 24, 24, ladder.x + 24, 119, 6) -- right rail
  
  -- room identification labels (adjusted for taller rooms)
  print("kit", 4, 98, 6)      -- kitchen (ground left)
  print("bed", 92, 98, 6)     -- bedroom (ground right)
  print("bath", 4, 66, 6)     -- bathroom (second left)
  print("liv", 92, 66, 6)     -- living (second right)
  print("attic", 52, 34, 6)   -- attic (top)
  
  -- kitchen tool production display (moved down for taller room)
  print("tool:", 4, 104, 7)
  print(tool_types[current_kitchen_tool], 4, 110, 11)
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
  -- draw rising water levels as blue rectangles from floor up
  for i, room in pairs(rooms) do
    if room.flood_level > 0 then
      local flood_height = flr(room.flood_level)
      -- draw water from bottom of room upward
      rectfill(room.x, room.y + room.h - flood_height, 
               room.x + room.w, room.y + room.h, 1)  -- dark blue water
    end
  end
end

function draw_hud()
  -- heads-up display showing game status and player feedback
  
  -- current score (survival time + repair bonuses)
  print("score: " .. score, 2, 2, 7)
  
  -- show currently carried tool
  if player.inventory then
    print("item: " .. player.inventory, 2, 8, 11)
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
  
  -- flood level progress bars for main floor rooms (moved to bottom)
  local bar_index = 0
  for i, room in pairs(rooms) do
    if room.name != "attic" then  -- skip attic in flood display
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
00000000777777777000000070000000700000007000000070000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777700007077000700770007007700070077000700000000000000000000000000000000000000000000000000000000000000000000000000
00700700777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00077000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00077000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00700700777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000c0500e0500f0501005012050140501505016050180501a0501b0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c050
001000001005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005
00100000060500a0500e0501105013050140501505016050170501805019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905
