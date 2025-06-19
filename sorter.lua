local S = minetest.get_translator("biblio")
local T = minetest.get_translator("mcl_enchanting")
local slot_style = "bgcolor[#080808BB;true]listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"

local inner_box_padding = 0.025
local slot_offset = 0.15
local slot_height = 0.5
local content_y_offset = slot_height

-- Получение всех зарегистрированных чар
local function get_registered_enchantments()
  local enchants = mcl_enchanting and mcl_enchanting.enchantments
  if type(enchants) ~= "table" then
    minetest.log("error", "[biblio] No enchantments found (mcl_enchanting.enchantments is nil)")
    return {}
  end

  local result = {}
  for id, def in pairs(enchants) do
    local raw = id:gsub("_", " ")
    local translated = def.name or T(raw)
    local show_name = #translated > 28 and raw:gsub("^%l", string.upper) or translated
    table.insert(result, {
      id = id,
      name = show_name,
      full_desc = def.description or translated,
      max_level = def.max_level or 1,
      groups = def.groups or {}
    })
  end
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

-- Разбивка по группам
local function group_enchantments_by_type(enchantments)
  local groups = {
    armor = {}, weapon = {}, tool = {}, bow = {}, fishing_rod = {}, other = {}
  }
  for _, e in ipairs(enchantments) do
    local added = false
    for g in pairs(e.groups) do
      if groups[g] then
        table.insert(groups[g], e)
        added = true
      end
    end
    if not added then
      table.insert(groups.other, e)
    end
  end

  -- сортировка чаров по имени внутри каждой группы
  for _, list in pairs(groups) do
    table.sort(list, function(a, b)
      return a.name:lower() < b.name:lower()
    end)
  end

  return groups
end

-- Отрисовка ячеек
local function slot_background(x0, y0, w, h)
  local lines = {}
  local spacing = 1.25
  for i = 0, h - 1 do
    for j = 0, w - 1 do
      table.insert(lines, ("image[%.3f,%.3f;1,1;gui_slot.png]"):format(
        x0 + j * spacing, y0 + i * spacing
      ))
    end
  end
  return table.concat(lines, "\n")
end

-- Блок-секция
local function section(x, y, w, h, color, slotspec)
  local lines = {}
  local y_shift = y + content_y_offset
  table.insert(lines, ("box[%.3f,%.3f;%.3f,%.3f;#000000]"):format(x, y_shift, w, h))
  table.insert(lines, ("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(
    x + inner_box_padding, y_shift + inner_box_padding,
    w - inner_box_padding * 2, h - inner_box_padding * 2,
    color
  ))
  if slotspec then
    local sx = x + slot_offset
    local sy = y_shift + slot_offset
    --table.insert(lines, slot_background(sx, sy, slotspec.w, slotspec.h))
    table.insert(lines, ("list[%s;%s;%.3f,%.3f;%d,%d;]"):format(
      slotspec.owner, slotspec.name, sx, sy, slotspec.w, slotspec.h
    ))
  end
  return table.concat(lines, "\n")
end

-- Основная форма
local function get_main_formspec(meta)
  return table.concat({
    "formspec_version[4]",
    
    "size[13.5,13.5]",
    "button[0.4,0.2;2,1;open_filter;" .. S("Filter") .. "]",
    ("label[%.3f,%.3f;%s]"):format(0.4, 1.0 + content_y_offset, S("Rejected (✕) - dst")),
    ("label[%.3f,%.3f;%s]"):format(4.8, 1.0 + content_y_offset, S("Insert enchanted books")),
    ("label[%.3f,%.3f;%s]"):format(9.0, 1.0 + content_y_offset, S("Matched (✓) - out")),
    section(0.3, 1.3, 3.8, 5.2, "#FFAAAA", { owner = "current_name", name = "dst", w = 3, h = 4 }),
    section(4.7, 1.3, 3.8, 5.2, "#AAAAFF", { owner = "current_name", name = "main", w = 3, h = 4 }),
    section(9.1, 1.3, 3.8, 5.2, "#AAFFAA", { owner = "current_name", name = "output", w = 3, h = 4 }),
    ("label[%.3f,%.3f;%s]"):format(1.75, 7.1 + content_y_offset, S("Player Inventory")),
    section(1.75, 7.5, 10.05, 5.15, "#DDDDDD", { owner = "current_player", name = "main", w = 8, h = 4 }),
    --"listring[current_player;main]",
    slot_style,
    "listring[current_name;main]",
    "listring[current_name;output]",
    "listring[current_name;dst]",
    "listring[current_player;main]"
  }, "\n")
end

-- Форма фильтрации
local function get_filter_formspec(meta)
  local lines = {
    "formspec_version[4]",
    "size[13.5,13.5]",
    "button[0.1,0.2;2,1;back;" .. S("Back") .. "]",
    "button[2.5,0.2;2,1;save;" .. S("Save") .. "]",
    ("label[5.2,0.7;%s]"):format(S("Select charms to match"))
  }

  local enchants = get_registered_enchantments()
  local grouped = group_enchantments_by_type(enchants)
  local ordered_groups = { "armor", "weapon", "tool", "bow", "fishing_rod", "other" }
  local y = 1.2
  local col = 0

  for _, group in ipairs(ordered_groups) do
    local group_list = grouped[group]
    if #group_list > 0 then
      --table.insert(lines, ("label[%.2f,%.2f;%s]"):format(0.2, y, group:gsub("^%l", string.upper)))
      y = y + 0.5
      for _, charm in ipairs(group_list) do
        local filter_key = "filter_" .. charm.id
        local level_key = "level_" .. charm.id
        local checked = meta:get_string(filter_key) == "true" and "true" or "false"
        local saved_level = meta:get_string(level_key)
        local selected_idx = 1
        if saved_level ~= "" then
          for i = 1, charm.max_level do
            if tostring(i) == saved_level then
              selected_idx = i + 1 -- +1, потому что первый элемент — "✕"
              break
            end
          end
        end
        local x = 0.2 + col * 4.4

        table.insert(lines, ("checkbox[%s,%.2f;%s;;%s]"):format(x, y + 0.32, filter_key, checked))
        table.insert(lines, ("tooltip[%s;%s]"):format(filter_key, charm.full_desc:gsub(";", " ")))
        table.insert(lines, ("label[%s,%.2f;%s]"):format(x + 0.6, y + 0.32, charm.name))

        if charm.max_level > 1 then
          local levels = { "✕" }
          for i = 1, charm.max_level do table.insert(levels, tostring(i)) end
          table.insert(lines, ("dropdown[%s,%.2f;1.5,0.6;%s;%s;%d]"):format(
            x + 2.4, y + 0.05, level_key, table.concat(levels, ","), selected_idx))
        end

        table.insert(lines, ("box[%s,%.2f;4,0.02;#99999955]"):format(x, y + 0.68))
        col = col + 1
        if col >= 3 then
          col = 0
          y = y + 0.7
        end
      end
      y = y + 0.5
    end
  end

  return table.concat(lines, "\n")
end

-- Проверка соответствия фильтру
local function passes_filter(stack, meta)
  if stack:get_name() ~= "mcl_enchanting:book_enchanted" then return false end
  local meta_table = stack:get_meta():to_table()
  local enchant_str = meta_table and meta_table.fields and meta_table.fields["mcl_enchanting:enchantments"]
  if not enchant_str then return false end

  local chunk, err = loadstring(enchant_str)
  if not chunk then return false end

  local ok, enchants = pcall(chunk)
  if not ok or type(enchants) ~= "table" then return false end

  for _, charm in ipairs(get_registered_enchantments()) do
    local filter_key = "filter_" .. charm.id
    local level_str = meta:get_string("level_" .. charm.id)
    local level = enchants[charm.id]
    if meta:get_string(filter_key) == "true" then
      if charm.max_level > 1 then
        local min_level = tonumber(level_str) or 1
        if level and level >= min_level then return true end
      else
        if level then return true end
      end
    end
  end

  return false
end

-- Регистрация блока
minetest.register_node("mcl_biblio:sorter", {
  description = "Biblio Enchanted Book Sorter",
  tiles = { "biblio_sorter_top.png", "biblio_sorter_top.png", "biblio_sorter_top.png",
    "biblio_sorter_top.png", "biblio_sorter_top.png", {
    name = "biblio_sorter_front_anim.png",
    animation = { type = "vertical_frames", aspect_w = 128, aspect_h = 128, length = 2.0 }
  } },
  groups = { cracky = 2, container = 2 },
  paramtype2 = "facedir",

  can_dig = function(pos, player)
    local inv = minetest.get_meta(pos):get_inventory()
    return inv:is_empty("main") and inv:is_empty("output") and inv:is_empty("dst")
  end,

  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    inv:set_size("main", 12)
    inv:set_size("output", 12)
    inv:set_size("dst", 12)
    meta:set_string("logistics_import_input", "main")
    meta:set_string("logistics_export_output", "output")
    meta:set_string("logistics_export_dst", "dst")
    meta:set_string("formspec", get_main_formspec(meta))
  end,

  on_hopper_in = function(pos, from_pos)
    --minetest.chat_send_all("[DEBUG] on_hopper_in called!")
    if from_pos.y <= pos.y then
      return false -- логирование
    end

    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local sinv = minetest.get_inventory({ type = "node", pos = from_pos })

    local slot_id, _ = mcl_util.get_eligible_transfer_item_slot(
      sinv, "main", inv, "main",
      function(stack)
        return not stack:is_empty() and stack:get_name() == "mcl_enchanting:book_enchanted"
      end
    )

    if slot_id then
      mcl_util.move_item_container(from_pos, pos, nil, slot_id, "main")
      --minetest.chat_send_all("[HOPPER] книга перемещена в input")
      return true
    end

    return false
  end,

  after_dig_node = function(pos, oldnode, oldmeta, digger)
    local inv = minetest.get_meta(pos):get_inventory()
    for _, listname in ipairs({ "main", "output", "dst" }) do
      for i = 1, inv:get_size(listname) do
        local stack = inv:get_stack(listname, i)
        if not stack:is_empty() then
          minetest.add_item(pos, stack)
        end
      end
    end
  end,

  allow_metadata_inventory_put = function(_, listname, index, stack, player)
    -- логирование
    --minetest.chat_send_all("[PUT] "..dump({listname, index, stack:get_name(), stack:get_count()}))
    if listname ~= "main" then return 0 end
    if not stack or stack:is_empty() then return 0 end
    if stack:get_name() ~= "mcl_enchanting:book_enchanted" then return 0 end
    return stack:get_count()
  end,

  on_metadata_inventory_put = function(pos, listname)
    if listname == "main" then
      -- логирование
      --minetest.chat_send_all("[TRIGGER] on_metadata_inventory_put → timer start")
      minetest.get_node_timer(pos):start(0.5)
    end
  end,

  allow_metadata_inventory_move = function(_, from_list, from_index, to_list, to_index, count, player)
    -- логирование
    --minetest.chat_send_all("[MOVE] "..dump({from_list, to_list, count}))
    if to_list ~= "main" then return 0 end
    return count
  end,

  on_timer = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    for i = 1, inv:get_size("main") do
      local stack = inv:get_stack("main", i)
      if not stack:is_empty() then
        local passed = passes_filter(stack, meta)
        local target = passed and "output" or "dst"
        -- логирование
        --minetest.chat_send_all("[SORT] "..stack:get_name().." → "..target)
        if inv:room_for_item(target, stack) then
          inv:add_item(target, stack)
          inv:set_stack("main", i, ItemStack(nil))
        end
        break
      end
    end
    return true
  end,

  on_receive_fields = function(pos, _, fields, _)
    local meta = minetest.get_meta(pos)
    if fields.quit then return end

    for _, charm in ipairs(get_registered_enchantments()) do
      local filter_key = "filter_" .. charm.id
      local level_key = "level_" .. charm.id

      if fields[filter_key] ~= nil then
        meta:set_string(filter_key, fields[filter_key])
      end

      if charm.max_level > 1 and fields[level_key] ~= nil then
        local val = fields[level_key]
        if val == "✕" then
          meta:set_string(level_key, "")
        else
          meta:set_string(level_key, val)
        end
      end
    end

    if fields.back or fields.save then
      meta:set_string("formspec", get_main_formspec(meta))
    else
      meta:set_string("formspec", get_filter_formspec(meta))
    end
  end,
})

if minetest.get_modpath("mcl_hopper") and hopper and hopper.add_container then
  hopper.add_container({
    { "top",    "mcl_biblio:sorter", "main" },
    { "bottom", "mcl_biblio:sorter", "output" },
    { "side",   "mcl_biblio:sorter", "dst" },
  })
  --minetest.log("action", "[biblio] Hopper container registered for sorter.")
  --minetest.chat_send_all("[biblio] Hopper container registered for sorter.")
end
