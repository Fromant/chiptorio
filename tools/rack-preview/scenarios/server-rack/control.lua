-- Isolated visual review scenario. No changes to the player's existing saves.
local function label(surface, text, pos, scale)
  rendering.draw_text{surface=surface, text=text, target=pos,
    color={r=.9,g=.85,b=.65}, alignment="center", scale=scale or 1,
    draw_on_ground=true}
end
script.on_init(function()
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({0,0},2)
  surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities_filtered{area={{-24,-20},{24,20}}}) do
    if e.type~="character" then e.destroy() end
  end
  local tiles={}
  for x=-24,24 do for y=-20,20 do
    tiles[#tiles+1]={name="refined-concrete",position={x,y}}
  end end
  surface.set_tiles(tiles)
  surface.daytime=.5
  surface.freeze_daytime=true
  surface.always_day=true
  local power=surface.create_entity{name="electric-energy-interface",position={-16,-11},force="player"}
  power.electric_buffer_size=1000000000
  power.power_production=100000000
  power.energy=1000000000
  for _,pos in ipairs({{-15,-10},{0,-10},{15,-10},{-15,1},{15,1},{-15,12},{0,12},{15,12}}) do
    surface.create_entity{name="substation",position=pos,force="player"}
  end
  storage.racks={}
  local function place(name,pos)
    local e=surface.create_entity{name=name,position=pos,force="player",raise_built=true}
    assert(e,"Preview could not create "..name)
    if name:find("server-rack",1,true) then
      storage.racks[#storage.racks+1]=e
      e.energy=1000000
      local box=e.bounding_box
      rendering.draw_rectangle{surface=surface,left_top=box.left_top,
        right_bottom=box.right_bottom,color={r=.6,g=.62,b=.48,a=.8},
        width=2,filled=false,draw_on_ground=true}
    end
    return e
  end
  label(surface,"3 x 3 SERVER ENCLOSURE  /  ART TRIAL",{0,-9},1.5)
  place("lab",{-8,-3.5})
  label(surface,"Vanilla lab",{-8,-.5})
  for i,name in ipairs({"server-rack","server-rack-east","server-rack-south","server-rack-west"}) do
    local x=-3+(i-1)*4
    place(name,{x,-3.5})
    label(surface,({"North / 3 x 3","East / 3 x 3","South / 3 x 3","West / 3 x 3"})[i],{x,-.5})
  end
  for _,x in ipairs({-6,-3,0,3,6}) do place("server-rack",{x,5.5}) end
  label(surface,"Point at a rack and press R / Shift+R",{0,9},1.1)
  surface.destroy_decoratives{area={{-24,-20},{24,20}}}
end)
-- Capture two frames from the real game for animation verification.
script.on_nth_tick(4,function()
  if game.tick ~= 120 and game.tick ~= 128 then return end
  for _,p in pairs(game.connected_players) do
    game.take_screenshot{player=p,surface=p.surface,position={0,0},
      resolution={1600,1100},zoom=1.8,show_gui=false,
      path="chiptorio/animation-"..game.tick..".png",anti_alias=true}
  end
end)
script.on_event(defines.events.on_player_created,function(event)
  local p=game.get_player(event.player_index)
  p.set_controller{type=defines.controllers.god}
  p.teleport({0,0},game.surfaces[1])
  p.zoom=1.6
  p.insert{name="server-rack",count=50}
  p.print("Rack review: R rotates, Shift+R reverses. Works while holding racks or pointing at a placed rack.")
end)
script.on_nth_tick(60,function()
  for _,e in ipairs(storage.racks or {}) do if e.valid then e.energy=1000000 end end
  if game.tick>=120 and not storage.captured then
    for _,p in pairs(game.connected_players) do
      game.take_screenshot{player=p,surface=p.surface,position={0,0},
        resolution={1600,1100},zoom=1.8,show_gui=false,
        path="chiptorio/server-rack-preview.png", anti_alias=true}
      storage.captured=true
    end
  end
end)
