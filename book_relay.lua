local S = minetest.get_translator("biblio")

--local slot_background = "bgcolor[#080808BB;true]background[5,5;1,1;gui_formbg.png]listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"
--local slot_background = "bgcolor[#080808BB;true]background[5,5;1,1;gui_formbg.png]listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"
local slot_background = "bgcolor[#080808BB;true]listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"

local function get_relay_formspec(meta)
  local selected = meta:get_string("source_slot")
  local selected_idx = 1
  if selected == "output" then selected_idx = 2
  elseif selected == "dst" then selected_idx = 3 end

  return table.concat({
    "formspec_version[4]",
    "size[20.3,14.25]",
    "label[0.3,0.6;Book Relay – Pickup source:]",
    "dropdown[0.3,0.8;3.2,0.5;source_slot;,✓ Matches, ✕ Rejects;", tostring(selected_idx), "]",
    --slot_background,
    slot_background,
    "list[current_name;main;0.3,1.5;16,7;]",
    "list[current_player;main;0.3,10.53;9,3;]",
    "listring[current_name;main]",
    "listring[current_player;main]",
  }, "\n")
end


minetest.register_node("mcl_biblio:book_relay", {
  description = "Book Relay",
  tiles = { "biblio_sorter_top.png", "biblio_sorter_top.png", "biblio_sorter_top.png",
    "biblio_sorter_top.png", "biblio_sorter_top.png", {
    name = "biblio_storage_anim.png",
    animation = { type = "vertical_frames", aspect_w = 128, aspect_h = 128, length = 4.0 }
  } },
  groups = {cracky = 2, container = 2},
  paramtype2 = "facedir",

  can_dig = function(pos, player)
    local inv = minetest.get_meta(pos):get_inventory()
    return inv:is_empty("main")
  end,

  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    inv:set_size("main", 112)  -- 16 * 7
    meta:set_string("formspec", get_relay_formspec(meta))
    meta:set_string("source_slot", "") -- по умолчанию не выбрано
    minetest.get_node_timer(pos):start(1.0)
  end,

  on_receive_fields = function(pos, _, fields, _)
  local meta = minetest.get_meta(pos)

  if fields.source_slot then
    if not meta:get_inventory():is_empty("main") then
      return
    end
    -- Удаляем все пробелы и лишние символы
    local val = fields.source_slot:gsub("^%s*", ""):gsub("%s*$", "")
    if val == "✓ Matches" then
      meta:set_string("source_slot", "output")
    elseif val == "✕ Rejects" then
      meta:set_string("source_slot", "dst")
    else
      meta:set_string("source_slot", "")
    end
  end

  meta:set_string("formspec", get_relay_formspec(meta))
end,

  allow_metadata_inventory_put = function(_, listname, _, stack)
    return listname == "main" and stack:get_name() == "mcl_enchanting:book_enchanted" and stack:get_count() or 0
  end,

  on_timer = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local source_slot = meta:get_string("source_slot")

    if source_slot ~= "output" and source_slot ~= "dst" then
      return true
    end

    for dx = -1, 1 do
      for dy = -1, 1 do
        for dz = -1, 1 do
          local target_pos = vector.add(pos, {x = dx, y = dy, z = dz})
          if not vector.equals(pos, target_pos) then
            local node = minetest.get_node_or_nil(target_pos)
            if node and node.name == "mcl_biblio:sorter" then
              local target_inv = minetest.get_meta(target_pos):get_inventory()
              for i = 1, target_inv:get_size(source_slot) do
                local stack = target_inv:get_stack(source_slot, i)
                if not stack:is_empty() and stack:get_name() == "mcl_enchanting:book_enchanted" then
                  if inv:room_for_item("main", stack) then
                    inv:add_item("main", stack)
                    target_inv:set_stack(source_slot, i, ItemStack(nil))
                    return true
                  end
                end
              end
            end
          end
        end
      end
    end

    return true
  end,
})

-- Подключение к воронке
if minetest.get_modpath("mcl_hopper") and hopper and hopper.add_container then
  hopper.add_container({
    {"top", "mcl_biblio:book_relay", "main"},
    {"bottom", "mcl_biblio:book_relay", "main"},
    {"side", "mcl_biblio:book_relay", "main"},
  })
  minetest.log("action", "[biblio] Hopper registered for book_relay.")
end