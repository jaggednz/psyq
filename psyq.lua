-- Psyq
--
-- a generative sequencer
-- inspired by the Psych Tone
-- and the double knot
--

function table.reduce(tbl, func, val)
  if val == nil then val = 0 end
     for i,v in pairs(tbl) do
         val = func(val, v)
     end
     return val
 end

engine.name = 'Thebangs'
thebangs = include('../thebangs/lib/thebangs_engine')

MusicUtil = require "musicutil"
scale_names = {}

notes = {}
edit_select = 1

lattice = require("lattice")

trck_one_pattern = nil
trck_two_pattern = nil

tracks = {
  {0,1,0,1, 0,1,0,1,  0,1,0,1, 0,1,0,1},
  {1,0,1,1, 0,0,1,1,  1,0,0,0, 1,0,1,0}
}

tones = {
  { channel=1, position=1, label='A', hz=110, arrow_offset = 2 },
  { channel=2, position=3, label='B', hz=220, arrow_offset = 4 },
  { channel=2, position=5, label='C', hz=330, arrow_offset = 6 }
}

--Borrowed from Awake
function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
  local num_to_add = 16 - #notes
  for i = 1, num_to_add do
    table.insert(notes, notes[16 - num_to_add])
  end
end

function init()
  -- generate available scales for quantisation
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end
  
  setup_params()
  
  print('NOTES::')
  build_scale()
  tab.print(notes)
  
  -- make the encoders easier to select
  norns.enc.sens(1,4)
  -- Start the redraw loop
  drawing=metro.init()
  drawing.time=0.1
  drawing.count=-1
  drawing.event=function()
    redraw()
  end
  drawing:start()
  
  --trck_one_pattern = lattice:new_pattern({
  --  action =  track_advance
  --})
  
  
  my_lattice = lattice:new{
    auto = true,
    meter = 4,
    ppqn = 96
  }

  -- make some patterns
  pattern_a = my_lattice:new_pattern{
    action = function(t)
      track_advance(1)
      -- Make some noize!
      new_tone = tones_hz()
      quant_tone_hz = MusicUtil.note_num_to_freq(
        MusicUtil.snap_note_to_array(
          MusicUtil.freq_to_note_num (new_tone),
          notes
        )
      )
      if new_tone > 0 then engine.hz(quant_tone_hz) end
    end,
    division = 1/8,
    enabled = true
  }
  
  pattern_b = my_lattice:new_pattern{
    action = function(t)
      track_advance(2)
    end,
    division = 1/7,
    enabled = true
  }
  
  my_lattice:start()
end

function tones_hz()
  local collect_hz = {}
  for i,tone in ipairs(tones) do
    if tracks[tone.channel][tone.position] == 1 then
      table.insert(collect_hz, tone.hz)
    end
  end
  
  return table.reduce(
    collect_hz,
    function (a, b)
        return a + b
    end
  )
end

function track_advance(trck_no)
  local track = tracks[trck_no]
  if trck_no == 1 then
    -- Implements a simple addition routine on odd outputs with inverted even outputs
    local carry = 1
    for out=1,16,2 do
      if carry == 1 then
        if track[out] then
          if track[out] == 1 then 
            track[out] = 0
            track[out+1] = 1
          else
            track[out] = 1
            track[out+1] = 0
            carry = 0
          end
        end
      end
    end
  else
    --Implements a simple shift register with input
    table.insert(track,1,track[16])
    table.remove(track,17)
  end
end

function enc(n,d)
  if n == 1 then
    edit_select = util.clamp(edit_select + d,1,7)
  end
  
  if n == 2 then
    if edit_select < 4 then
      tones[edit_select].hz = util.clamp(tones[edit_select].hz + d, 40, 1600)
    end
    if edit_select == 4 then params:set("clock_tempo",params:get("clock_tempo")+d) end
  end
  
  if n == 3 then
    if edit_select < 4 then
      tones[edit_select].position = tones[edit_select].position + d
      if tones[edit_select].position > 16 then 
        tones[edit_select].position = 1
        tones[edit_select].channel = tones[edit_select].channel == 2 and 1 or 2
      end
      if tones[edit_select].position < 1 then 
        tones[edit_select].position = 16
        tones[edit_select].channel = tones[edit_select].channel == 2 and 1 or 2
      end
    end
  end
  
end

function key()
end

function redraw()
  screen.clear()
  
  screen.level(2)
  
  for otpt = 1,16 do
    screen.level(tracks[1][otpt] == 1 and 15 or 1)
    screen.rect((otpt*6-4),6,4,4)
    screen.fill()
    screen.level(2)
    screen.rect((otpt*6-4),6,4,4)
    screen.stroke()
  end
  
  for otpt = 1,16 do
    screen.level(tracks[2][otpt] == 1 and 15 or 1)
    screen.rect((otpt*6-4),54,4,4)
    screen.fill()
    screen.level(2)
    screen.rect((otpt*6-4),54,4,4)
    screen.stroke()
  end
  
  -- TODO use tones label
  for i,tone in ipairs(tones) do
    draw_tone_menu_item(i,tone)
    draw_tone_menu_arrow(i,tone)
  end
  
  draw_menu_item(params:get("clock_tempo") .. 'bpm', 22, edit_select == 4)
  draw_menu_item('Trig.',    30, edit_select == 5)
  draw_menu_item('SUM',    38, edit_select == 6)
  draw_menu_item('DATA',  46, edit_select == 7)
  
  screen.update()
end

function draw_menu_item(label, y_pos, selected)
  screen.font_size(8)
  
  if selected then
    screen.level(3)
    screen.rect(98,y_pos-6,30,8)
    screen.stroke()
    screen.level(15)
  else 
    screen.level(8)
  end
  screen.move(112,y_pos)
  screen.text_center(label)
end

function draw_tone_menu_item(i,tone)
  if edit_select == i then
      screen.level(3)
      screen.rect(((i)*32)-30,23,32,14)
      screen.stroke()
      screen.level(15)
    else 
      screen.level(8)
    end
    
    screen.font_size(10)
    screen.move(((i)*32)-28,34)
    screen.text(tone.label .. ':')
    screen.font_size(8)
    screen.move(((i)*32-2),34)
    screen.text_right(tone.hz)
end

function draw_tone_menu_arrow(i,tone)
  if edit_select == i then
    screen.level(8)
  else
    screen.level(4)
  end
  if tone.channel == 1 then
    screen.move(((i)*32)-20,21)
    screen.line_rel(7, 0)
    screen.move(((i)*32)-16,21)
    screen.line_rel(0, -tone.arrow_offset)
    screen.line((tone.position*6-2),21-tone.arrow_offset)
    screen.line_rel(0, tone.arrow_offset-10)
    screen.line_rel(-2,2)
    screen.line_rel(3,0)
    screen.stroke()
  else
    screen.move(((i)*32)-20,39)
    screen.line_rel(7, 0)
    screen.move(((i)*32)-16,39)
    screen.line_rel(0, tone.arrow_offset)
    screen.line((tone.position*6-2),39+tone.arrow_offset)
    screen.line_rel(0, 10-tone.arrow_offset)
    screen.line_rel(-2,-2)
    screen.line_rel(3,0)
    screen.stroke()
  end
end

function setup_params()
  
  params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 11,
    action = function() build_scale() end}
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}
  
  -- TheBangs engine params
  --TODO sort these better
  
  cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
  params:add{type="control",id="amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_MOD1 = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="mod1",controlspec=cs_MOD1,
    action=function(x) engine.mod1(x/100) end}
  
  cs_MOD2 = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="mod2",controlspec=cs_MOD2,
    action=function(x) engine.mod2(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}
  
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  params:add{type="control",id="pan",controlspec=cs_PAN,
    action=function(x) engine.pan(x) end}  
  
  params:add_separator()
  thebangs.add_additional_synth_params()
  
  params:add_separator()
  thebangs.add_voicer_params()
  
end

