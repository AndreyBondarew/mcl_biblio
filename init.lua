-- init.lua

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

minetest.log("action", "[BIBLIO] init.lua loaded")
dofile(modpath .. "/sorter.lua")
dofile(modpath .. "/book_relay.lua")
dofile(modpath .. "/crafts.lua")