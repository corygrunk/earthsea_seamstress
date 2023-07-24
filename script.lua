-- earthsea: pattern instrument
-- 1.1.0 @tehn
-- llllllll.co/t/21349
--
-- port to seamstess by @corygrunk
--
-- subtractive polysynth
-- controlled by midi or grid
--
-- grid pattern player:
-- 1 1 record toggle
-- 1 2 play toggle
-- 1 8 transpose mode

local tab = require 'tabutil'
local pattern_time = require 'pattern_time'

local MusicUtil = require 'musicutil'
local note_display_name = '--'

local g = grid.connect()
Midi = midi.connect_output()

local mode_transpose = 0
local root = { x=5, y=5 }
local trans = { x=5, y=5 }
local lit = {}

local screen_framerate = 15
local screen_refresh_metro

local MAX_NUM_VOICES = 16

local options = {
  OUTPUT = {"midi"}
}

-- pythagorean minor/major, kinda
local ratios = { 1, 9/8, 6/5, 5/4, 4/3, 3/2, 27/16, 16/9 }
local base = 27.5 -- low A

local function getHz(deg,oct)
  return base * ratios[deg] * (2^oct)
end

local function getHzET(note)
  return 55*2^(note/12)
end

-- CHECK THIS CHECK THIS CHECK THIS -- I WROTE THIS
local function stop_all_midi_notes()
  for i = 1, 127 do
    Midi:note_off(i, 96, 1)
  end
end

-- current count of active voices
local nvoices = 0

function init()
  -- m = midi.connect()
  -- m.event = midi_event
  midi:connect_output(1)

  pat = pattern_time.new()
  pat.process = grid_note_trans

  params:add_separator()
  
  -- TODO: MIDI PORT & CHANNEL SELECT SHOULD GO HERE
  params:add{type = "option", id = "output", name = "output",
    options = options.OUTPUT,
    action = function(value)
      -- nothing to see here
    end
  }
  
  stop_all_midi_notes()

  params:bang()

  if g then gridredraw() end

  screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function(stage)
    redraw()
  end
  screen_refresh_metro:start(1 / screen_framerate)

  local startup_ani_count = 1
  local startup_ani_metro = metro.init()
  startup_ani_metro.event = function(stage)
    startup_ani_count = startup_ani_count + 1
  end
  startup_ani_metro:start( 0.1, 3 )
  

end

function g.key(x, y, z)
  if x == 1 then
    if z == 1 then
      if y == 1 and pat.rec == 0 then
        mode_transpose = 0
        trans.x = 5
        trans.y = 5
        pat:stop()
        stop_all_midi_notes()
        pat:clear()
        pat:rec_start()
      elseif y == 1 and pat.rec == 1 then
        pat:rec_stop()
        if pat.count > 0 then
          root.x = pat.event[1].x
          root.y = pat.event[1].y
          trans.x = root.x
          trans.y = root.y
          pat:start()
        end
      elseif y == 2 and pat.play == 0 and pat.count > 0 then
        if pat.rec == 1 then
          pat:rec_stop()
        end
        pat:start()
      elseif y == 2 and pat.play == 1 then
        pat:stop()
        stop_all_midi_notes()
        nvoices = 0
        lit = {}
      elseif y == 8 then
        mode_transpose = 1 - mode_transpose
      end
    end
  else
    if mode_transpose == 0 then
      local e = {}
      e.id = x*8 + y
      e.x = x
      e.y = y
      e.state = z
      pat:watch(e)
      grid_note(e)
    else
      trans.x = x
      trans.y = y
    end
  end
  gridredraw()
end

local function start_note(id)
  Midi:note_on(id, 96, 1)
  note_display_name = MusicUtil.note_num_to_name(id)
  redraw()
end  

local function stop_note(id)
  Midi:note_off(id, 96, 1)
end

function grid_note(e)
  local note = ((7-e.y)*5) + e.x
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      --engine.start(id, getHz(x, y-1))
      --print("grid > "..e.id.." "..note)
      start_note(e.id, note)
      lit[e.id] = {}
      lit[e.id].x = e.x
      lit[e.id].y = e.y
      nvoices = nvoices + 1
    end
  else
    if lit[e.id] ~= nil then
      -- engine.stop(e.id)
      Midi:note_off(e.id, 96, 1)
      lit[e.id] = nil
      nvoices = nvoices - 1
    end
  end
  gridredraw()
end

function grid_note_trans(e)
  local note = ((7-e.y+(root.y-trans.y))*5) + e.x + (trans.x-root.x)
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      --engine.start(id, getHz(x, y-1))
      --print("grid > "..id.." "..note)
      start_note(e.id) -- TODO THIS SHOULD MAYBE BE NOTE INSTEAD OF e.ID???
      lit[e.id] = {}
      lit[e.id].x = e.x + trans.x - root.x
      lit[e.id].y = e.y + trans.y - root.y
      nvoices = nvoices + 1
    end
  else
    stop_note(e.id)
    lit[e.id] = nil
    nvoices = nvoices - 1
  end
  gridredraw()
end

function gridredraw()
  g:all(0)
  g:led(1,1,2 + pat.rec * 10)
  g:led(1,2,2 + pat.play * 10)
  g:led(1,8,2 + mode_transpose * 10)

  if mode_transpose == 1 then g:led(trans.x, trans.y, 4) end
  for i,e in pairs(lit) do
    g:led(e.x, e.y,15)
  end

  g:refresh()
end



function redraw()
  screen.clear()
  screen.color(180, 255, 252, 0.8)
  screen.move(20,20)
  screen.text('earthsea')
  screen.move(20,30)
  screen.color(213, 225, 229, 0.8)
  screen.text('note: ' .. note_display_name)
  screen.refresh()
end

function note_on(note, vel)
  if nvoices < MAX_NUM_VOICES then
    --engine.start(id, getHz(x, y-1))
    engine.start(note, getHzET(note))
    start_screen_note(note)
    nvoices = nvoices + 1
  end
end

function note_off(note, vel)
  engine.stop(note)
  stop_screen_note(note)
  nvoices = nvoices - 1
end


function midi_event(data)
  if #data == 0 then return end
  local msg = midi.to_msg(data)

  -- Note off
  if msg.type == "note_off" then
    note_off(msg.note)

    -- Note on
  elseif msg.type == "note_on" then
    note_on(msg.note, msg.vel / 127)

--[[
    -- Key pressure
  elseif msg.type == "key_pressure" then
    set_key_pressure(msg.note, msg.val / 127)

    -- Channel pressure
  elseif msg.type == "channel_pressure" then
    set_channel_pressure(msg.val / 127)

    -- Pitch bend
  elseif msg.type == "pitchbend" then
    local bend_st = (util.round(msg.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
    local bend_range = params:get("bend_range")
    set_pitch_bend(bend_st * bend_range)

  ]]--
  end

end


function cleanup()
  pat:stop()
  pat = nil
end
