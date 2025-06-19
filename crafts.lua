minetest.register_craft({
  output = "mcl_biblio:sorter",
  recipe = {
		{ "mcl_core:iron_ingot", "mesecons:redstone", "mcl_core:iron_ingot", },
		{ "", "mcl_enchanting:book_enchanted", "", },
		{ "mcl_core:gold_ingot", "mesecons:redstone", "mcl_core:gold_ingot", },
	}
})

minetest.register_craft({
  output = "mcl_biblio:book_relay",
  recipe = {
		{ "mcl_core:iron_ingot", "mesecons:redstone", "mcl_core:iron_ingot", },
		{ "", "mcl_enchanting:book_enchanted", "", },
		{ "mcl_chests:chest", "mcl_chests:chest", "mcl_chests:chest", },
	}
})