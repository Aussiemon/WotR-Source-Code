-- chunkname: @scripts/helpers/profile_helper.lua

ProfileHelper = ProfileHelper or {}

ProfileHelper.find_gear_by_slot = function (self, gear_table, slot_name)
	for i, gear in ipairs(gear_table) do
		if self:gear_slot(gear.name) == slot_name then
			return gear, i
		end
	end
end

ProfileHelper.find_gear_by_name = function (self, gear_table, gear_name)
	for i, gear in ipairs(gear_table) do
		if gear.name == gear_name then
			return gear, i
		end
	end
end

ProfileHelper.find_gear_by_type = function (self, gear_table, gear_type)
	for i, gear in ipairs(gear_table) do
		if Gear[gear.name].gear_type == gear_type then
			return gear, i
		end
	end
end

ProfileHelper.remove_gear_by_slot = function (self, gear_table, gear_slot)
	local gear, index = self:find_gear_by_slot(gear_table, gear_slot)

	if index then
		table.remove(gear_table, index)
	end
end

ProfileHelper.remove_gear_by_type = function (self, gear_table, gear_type)
	local gear, index = self:find_gear_by_type(gear_table, gear_type)

	if index then
		table.remove(gear_table, index)
	end
end

ProfileHelper.gear_slot = function (self, gear_name)
	return GearTypes[Gear[gear_name].gear_type].inventory_slot
end

ProfileHelper.find_complementing_gear = function (self, solo_gear_name, gear_table)
	local solo_gear = Gear[solo_gear_name]
	local solo_gear_type = GearTypes[solo_gear.gear_type]
	local solo_gear_slot = solo_gear_type.inventory_slot

	if solo_gear_slot == "shield" then
		local two_handed_wpn = self:find_gear_by_slot(gear_table, "two_handed_weapon")

		if two_handed_wpn and (not table.contains(solo_gear_type.unwield_slots_on_wield, "two_handed_weapon") or solo_gear_type.unwield_slot_exception_gear_types[two_handed_wpn.gear_type]) then
			return two_handed_wpn
		end

		local one_handed_wpn = self:find_gear_by_slot(gear_table, "one_handed_weapon")

		if one_handed_wpn and (not table.contains(solo_gear_type.unwield_slots_on_wield, "one_handed_weapon") or solo_gear_type.unwield_slot_exception_gear_types[one_handed_wpn.gear_type]) then
			return one_handed_wpn
		end

		local dagger = self:find_gear_by_slot(gear_table, "dagger")

		if dagger and (not table.contains(solo_gear_type.unwield_slots_on_wield, "dagger") or solo_gear_type.unwield_slot_exception_gear_types[dagger.gear_type]) then
			return dagger
		end
	else
		local shield = self:find_gear_by_slot(gear_table, "shield")

		if shield and (not table.contains(solo_gear_type.unwield_slots_on_wield, "shield") or solo_gear_type.unwield_slot_exception_gear_types[shield.gear_type]) then
			return shield
		end
	end
end

ProfileHelper.set_gear_patterns = function (self, unit, meshes, pattern)
	for mesh_name, materials in pairs(meshes) do
		if script_data.pattern_debug then
			print("MESH", mesh_name)
		end

		local mesh = Unit.mesh(unit, mesh_name)

		for _, material_name in ipairs(materials) do
			if script_data.pattern_debug then
				print("MATERIAL", material_name)
			end

			local material = Mesh.material(mesh, material_name)

			Material.set_vector3(material, "tint_rgb_a", pattern.personal_pattern_tint_primary:unbox())
			Material.set_vector3(material, "tint1_rgb_a", pattern.personal_pattern_tint_secondary:unbox())
			Material.set_vector3(material, "tint_rgb", pattern.team_pattern_tint_primary:unbox())
			Material.set_vector3(material, "tint1_rgb", pattern.team_pattern_tint_secondary:unbox())
			Material.set_vector2(material, "uv_offset", Vector2(pattern.personal_pattern_u, pattern.personal_pattern_v))
			Material.set_vector2(material, "material_tint_mask_blue_uv_offset", Vector2(pattern.team_pattern_u, pattern.team_pattern_v))
		end
	end
end

ProfileHelper.build_profile_from_game_object = function (self, game, profile_obj_id, inventory)
	local profile = {}
	local armour = NetworkLookup.armours[GameSession.game_object_field(game, profile_obj_id, "armour")]
	local helmet_name = NetworkLookup.helmets[GameSession.game_object_field(game, profile_obj_id, "helmet")]

	profile.armour = armour

	local gear_table = {}

	for slot_name, slot in pairs(inventory:slots()) do
		local gear = slot.gear

		if gear then
			local attachments = gear:attachments()

			gear_table[#gear_table + 1] = {
				name = gear:name(),
				attachments = attachments
			}
		end
	end

	profile.gear = gear_table
	profile.helmet = {
		name = helmet_name
	}

	local perk_table = {}

	for _, slot in ipairs(PerkSlots) do
		local perk_lookup = GameSession.game_object_field(game, profile_obj_id, slot.game_object_field)

		if perk_lookup ~= 0 then
			local perk = NetworkLookup.perks[perk_lookup]

			perk_table[slot.name] = perk
		end
	end

	profile.perks = perk_table
	profile.display_name = L("your_killers_profile")

	return profile
end

ProfileHelper.is_entity_avalible = function (self, unlock_type, unlock_key, entity_type, entity_name, release_name)
	if GameSettingsDevelopment.unlock_all then
		return true
	end

	local release_setting = ReleaseSettings[release_name or "default"]

	fassert(release_setting, "Invalid release setting %q", release_name)

	if release_setting == "test" then
		return true
	end

	local profile_data = Managers.persistence:profile_data()

	if not profile_data then
		if unlock_type == "profile" and unlock_key == PlayerProfiles[1].unlock_key then
			return true
		else
			return false, "rank_not_met"
		end
	end

	local entity_rank_met = self:entity_rank_met(unlock_type, unlock_key, profile_data)

	if IS_DEMO then
		local available_in_demo = self:available_in_demo(entity_type, entity_name)

		if available_in_demo then
			return true
		else
			return false, "locked_in_demo"
		end
	elseif entity_rank_met then
		local entity_owned = entity_type == "profile" and (entity_name == "footman" or entity_name == "crossbowman" or entity_name == "archer" or entity_name == "footknight")

		entity_owned = entity_owned or self:entity_owned(entity_type, entity_name, profile_data)

		if entity_owned then
			return true
		else
			return false, "not_owned"
		end
	else
		return false, "rank_not_met"
	end
end

ProfileHelper.entity_rank_met = function (self, unlock_type, unlock_key, profile_data)
	local required_rank = ProfileHelper:required_entity_rank(unlock_type, unlock_key)

	if not required_rank then
		return true
	end

	return required_rank <= profile_data.attributes.rank
end

ProfileHelper.available_in_demo = function (self, unlock_category, unlock_key)
	for _, demo_unlocks in ipairs(DemoSettings.unlocks) do
		if demo_unlocks.category_name == unlock_category and demo_unlocks.name == unlock_key then
			return true
		end
	end
end

ProfileHelper.required_entity_rank = function (self, unlock_type, unlock_key)
	local required_rank

	for i = 0, #RANKS do
		local rank = RANKS[i]

		for _, unlock in ipairs(rank.unlocks) do
			if unlock.category == unlock_type and unlock.name == unlock_key then
				required_rank = i

				return i
			end
		end
	end
end

ProfileHelper.entity_owned = function (self, entity_type, entity_name, profile_data)
	for _, e in ipairs(profile_data.entities) do
		if e.type == entity_type and e.name == entity_name then
			return true
		end
	end
end

ProfileHelper.exists_in_market = function (self, market_item_name)
	local market_item = Managers.persistence:market().items[market_item_name]

	return market_item and true or false
end

ProfileHelper.xp_left_to_rank = function (self, rank)
	local profile_data = Managers.persistence:profile_data()

	if profile_data then
		local xp = math.floor(profile_data.attributes.experience)
		local xp_rank = RANKS[rank].xp.base

		return math.max(xp_rank - xp, 0)
	end
end

ProfileHelper.has_perk = function (self, perk_name, character_profile)
	for _, profile_perk_name in pairs(character_profile.perks) do
		if perk_name == profile_perk_name then
			return true
		end
	end
end

ProfileHelper.perk_multiplier = function (self, perk_name, perk_multiplier, character_profile)
	if ProfileHelper:has_perk(perk_name, character_profile) then
		return Perks[perk_name][perk_multiplier]
	else
		return 1
	end
end
