pico-8 cartridge // http://www.pico-8.com
ver 4
__lua__
-- dollhouse leak fixer
-- a retro-inspired leak fixing game

-- game constants
local screen_w = 128
local screen_h = 128
local room_w = 32
local room_h = 24

-- game state
local gamestate = "playing"
local score = 0
local time_elapsed = 0
local feedback_msg = ""
local feedback_timer = 0

-- player
local player = {
  x = 64,
  y = 64,
  w = 8,
  h = 8,
  sprite = 1,
  room = 1,
  inventory = nil
}

-- rooms (kitchen, bedroom, bathroom, living, attic)
local rooms = {
  {id=1, name="kitchen", x=0, y=48, w=32, h=24, flood_level=0, leak=false},
  {id=2, name="bedroom", x=32, y=48, w=32, h=24, flood_level=0, leak=false},
  {id=3, name="bathroom", x=64, y=48, w=32, h=24, flood_level=0, leak=false},
  {id=4, name="living", x=96, y=48, w=32, h=24, flood_level=0, leak=false},
  {id=5, name="attic", x=32, y=24, w=64, h=24, flood_level=0, leak=false, critical=true}
}

-- tools
local tool_types = {"pot", "putty", "wrench", "rag", "plank"}
local current_kitchen_tool = 1
local tool_cycle_timer = 0
local tool_cycle_interval = 180 -- 3 seconds at 60fps

-- leaks
local leak_timer = 0
local leak_interval = 300 -- 5 seconds initial interval
local attic_multiplier = 1

-- flood mechanics
local flood_rate = 0.1
local max_flood_level = 20

function _init()
  -- initialize game
  spawn_random_leak()
end

function _update60()
  if gamestate == "playing" then
    update_game()
  elseif gamestate == "gameover" then
    update_gameover()
  end
end

function update_game()
  -- update timers
  time_elapsed += 1
  score = flr(time_elapsed / 60) -- score based on seconds survived
  tool_cycle_timer += 1
  leak_timer += 1
  
  -- update feedback timer
  if feedback_timer > 0 then
    feedback_timer -= 1
  end
  
  -- cycle kitchen tool
  if tool_cycle_timer >= tool_cycle_interval then
    current_kitchen_tool = (current_kitchen_tool % #tool_types) + 1
    tool_cycle_timer = 0
  end
  
  -- spawn new leaks
  if leak_timer >= leak_interval then
    spawn_random_leak()
    leak_timer = 0
    -- gradually decrease interval (increase difficulty)
    leak_interval = max(120, leak_interval - 5)
  end
  
  -- update player
  update_player()
  
  -- update flooding
  update_flooding()
  
  -- check game over
  check_game_over()
end

function update_player()
  local old_x, old_y = player.x, player.y
  
  -- movement
  if btn(0) then player.x -= 1 end -- left
  if btn(1) then player.x += 1 end -- right
  if btn(2) then player.y -= 1 end -- up
  if btn(3) then player.y += 1 end -- down
  
  -- keep player in bounds
  player.x = mid(0, player.x, screen_w - player.w)
  player.y = mid(0, player.y, screen_h - player.h)
  
  -- update player room
  update_player_room()
  
  -- interaction
  if btnp(4) then -- x button
    interact()
  end
end

function update_player_room()
  for i, room in pairs(rooms) do
    if player.x >= room.x and player.x < room.x + room.w and
       player.y >= room.y and player.y < room.y + room.h then
      player.room = room.id
      break
    end
  end
end

function interact()
  local room = rooms[player.room]
  
  -- kitchen: pick up tool
  if room.name == "kitchen" and not player.inventory then
    player.inventory = tool_types[current_kitchen_tool]
    feedback_msg = "picked up " .. player.inventory
    feedback_timer = 120
    sfx(0) -- pickup sound
  
  -- other rooms: use tool on leak
  elseif room.leak and player.inventory then
    if can_fix_leak(room, player.inventory) then
      fix_leak(room, player.inventory)
      feedback_msg = "leak fixed!"
      feedback_timer = 120
      player.inventory = nil
      sfx(1) -- fix sound
    else
      feedback_msg = "wrong tool! need: " .. get_correct_tools(room)
      feedback_timer = 180
      sfx(2) -- wrong tool sound
    end
  end
end

function can_fix_leak(room, tool)
  -- room-specific tool compatibility
  if room.name == "bedroom" then
    return tool == "pot" or tool == "rag"
  elseif room.name == "bathroom" then
    return tool == "wrench" or tool == "putty"
  elseif room.name == "living" then
    return tool == "plank" or tool == "putty"
  elseif room.name == "attic" then
    return tool == "wrench" or tool == "putty"
  end
  return false
end

function get_correct_tools(room)
  if room.name == "bedroom" then
    return "pot/rag"
  elseif room.name == "bathroom" then
    return "wrench/putty"
  elseif room.name == "living" then
    return "plank/putty"
  elseif room.name == "attic" then
    return "wrench/putty"
  end
  return "unknown"
end

function fix_leak(room, tool)
  room.leak = false
  room.flood_level = max(0, room.flood_level - 5)
  
  -- attic fixes reduce global flood multiplier
  if room.name == "attic" then
    attic_multiplier = 1
  end
  
  score += 10 -- bonus points for fixing leak
end

function spawn_random_leak()
  -- find rooms that can have new leaks
  local available_rooms = {}
  for i, room in pairs(rooms) do
    if not room.leak and room.flood_level < max_flood_level then
      add(available_rooms, room)
    end
  end
  
  if #available_rooms > 0 then
    local room = available_rooms[flr(rnd(#available_rooms)) + 1]
    room.leak = true
    
    -- attic leaks are critical
    if room.name == "attic" then
      attic_multiplier = 2
    end
  end
end

function update_flooding()
  for i, room in pairs(rooms) do
    if room.leak then
      room.flood_level += flood_rate * attic_multiplier
      room.flood_level = min(room.flood_level, max_flood_level)
    end
  end
end

function check_game_over()
  local flooded_rooms = 0
  for i, room in pairs(rooms) do
    if room.name != "attic" and room.flood_level >= max_flood_level then
      flooded_rooms += 1
    end
  end
  
  if flooded_rooms >= 4 then
    gamestate = "gameover"
  end
end

function update_gameover()
  if btnp(4) then -- restart
    _init()
    gamestate = "playing"
  end
end

function _draw()
  cls()
  
  if gamestate == "playing" then
    draw_game()
  elseif gamestate == "gameover" then
    draw_gameover()
  end
end

function draw_game()
  -- draw house layout
  draw_house()
  
  -- draw leaks
  draw_leaks()
  
  -- draw flooding
  draw_flooding()
  
  -- draw player
  spr(player.sprite, player.x, player.y)
  
  -- draw hud
  draw_hud()
end

function draw_house()
  -- house outline
  rect(0, 24, 127, 95, 7)
  
  -- room dividers
  line(32, 24, 32, 95, 7)  -- bedroom | bathroom
  line(64, 24, 64, 95, 7)  -- bathroom | living
  line(96, 24, 96, 95, 7)  -- living | edge
  line(0, 48, 127, 48, 7)  -- attic | main floor
  line(32, 24, 96, 24, 7)  -- attic floor
  
  -- room labels
  print("kit", 4, 50, 6)
  print("bed", 36, 50, 6)
  print("bath", 66, 50, 6)
  print("live", 100, 50, 6)
  print("attic", 48, 28, 6)
  
  -- kitchen production line
  print("tool:", 4, 76, 7)
  print(tool_types[current_kitchen_tool], 4, 82, 11)
end

function draw_leaks()
  for i, room in pairs(rooms) do
    if room.leak then
      -- simple leak indicator
      circfill(room.x + room.w/2, room.y + 4, 2, 12)
      
      -- attic warning
      if room.name == "attic" then
        if time_elapsed % 30 < 15 then -- blink
          print("!", room.x + room.w/2 - 2, room.y + 10, 8)
        end
      end
    end
  end
end

function draw_flooding()
  for i, room in pairs(rooms) do
    if room.flood_level > 0 then
      local flood_height = flr(room.flood_level)
      rectfill(room.x, room.y + room.h - flood_height, 
               room.x + room.w, room.y + room.h, 1)
    end
  end
end

function draw_hud()
  -- score
  print("score: " .. score, 2, 2, 7)
  
  -- carried item
  if player.inventory then
    print("item: " .. player.inventory, 2, 8, 11)
  end
  
  -- feedback message
  if feedback_timer > 0 then
    local color = 11
    if sub(feedback_msg, 1, 5) == "wrong" then
      color = 8 -- red for error
    elseif sub(feedback_msg, 1, 4) == "leak" then
      color = 11 -- green for success
    end
    print(feedback_msg, 2, 14, color)
  end
  
  -- attic warning
  if rooms[5].leak then
    print("attic leak!", 80, 2, 8)
  end
  
  -- flood indicators (simple bars)
  for i, room in pairs(rooms) do
    if room.name != "attic" then
      local bar_x = 2 + (i-1) * 20
      local bar_y = 120
      rect(bar_x, bar_y, bar_x + 16, bar_y + 4, 7)
      if room.flood_level > 0 then
        local fill_width = flr((room.flood_level / max_flood_level) * 16)
        rectfill(bar_x, bar_y, bar_x + fill_width, bar_y + 4, 8)
      end
    end
  end
end

function draw_gameover()
  print("game over!", 40, 50, 8)
  print("final score: " .. score, 35, 60, 7)
  print("press x to restart", 25, 70, 6)
end

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