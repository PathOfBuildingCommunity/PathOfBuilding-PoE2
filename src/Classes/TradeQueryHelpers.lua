M = {}

function M.GetTradeCategory(slotName, existingItem)
	if slotName:find("^Weapon %d") then
		if existingItem then
			if existingItem.type == "Shield" then
				return "armour.shield", "Shield"
			elseif existingItem.type == "Focus" then
				return "armour.focus", "Focus"
			elseif existingItem.type == "Buckler" then
				return "armour.buckler", "Buckler"
			elseif existingItem.type == "Quiver" then
				return "armour.quiver", "Quiver"
			elseif existingItem.type == "Bow" then
				return "weapon.bow", "Bow"
			elseif existingItem.type == "Crossbow" then
				return "weapon.crossbow", "Crossbow"
			elseif existingItem.type == "Talisman" then
				return "weapon.talisman", "Talisman"	
			elseif existingItem.type == "Staff" and existingItem.base.subType == "Warstaff" then
				return "weapon.warstaff", "Quarterstaff"
			elseif existingItem.type == "Staff" then
				return "weapon.staff", "Staff"
			elseif existingItem.type == "Two Hand Sword" then
				return "weapon.twosword", "2HSword"
			elseif existingItem.type == "Two Hand Axe" then
				return "weapon.twoaxe", "2HAxe"
			elseif existingItem.type == "Two Hand Mace" then
				return "weapon.twomace", "2HMace"
			elseif existingItem.type == "Fishing Rod" then
				return "weapon.rod", "FishingRod"
			elseif existingItem.type == "One Hand Sword" then
				return "weapon.onesword", "1HSword"
			elseif existingItem.type == "Spear" then
				return "weapon.spear", "Spear"
			elseif existingItem.type == "Flail" then
				return "weapon.flail", "weapon.flail"
			elseif existingItem.type == "One Hand Axe" then
				return "weapon.oneaxe", "1HAxe"
			elseif existingItem.type == "One Hand Mace" then
				return "weapon.onemace", "1HMace"
			elseif existingItem.type == "Sceptre" then
				return "weapon.sceptre", "Sceptre"
			elseif existingItem.type == "Wand" then
				return "weapon.wand", "Wand"
			elseif existingItem.type == "Dagger" then
				return "weapon.dagger", "Dagger"
			elseif existingItem.type == "Claw" then
				return "weapon.claw", "Claw"
			elseif existingItem.type:find("Two Hand") ~= nil then
				return "weapon.twomelee", "2HWeapon"
			elseif existingItem.type:find("One Hand") ~= nil then
				return "weapon.one", "1HWeapon"
			else
				return nil, nil
			end
		else
			-- Item does not exist in this slot so assume 1H weapon
			return "weapon.one", "1HWeapon"
		end
	elseif slotName == "Body Armour" then
		return "armour.chest", "Chest"
	elseif slotName == "Helmet" then
		return "armour.helmet", "Helmet"
	elseif slotName == "Gloves" then
		return "armour.gloves", "Gloves"
	elseif slotName == "Boots" then
		return "armour.boots", "Boots"
	elseif slotName == "Amulet" then
		return "accessory.amulet", "Amulet"
	elseif slotName == "Ring 1" or slotName == "Ring 2" or slotName == "Ring 3" then
		return "accessory.ring", "Ring"
	elseif slotName == "Belt" then
		return "accessory.belt", "Belt"
	elseif slotName:find("Jewel") ~= nil then
		return "jewel", "Jewel"
	elseif slotName:find("Flask 1") ~= nil then
		return "flask.life", "Life Flask"
	elseif slotName:find("Flask 2") ~= nil then
		return "flask.mana", "Mana Flask"
	elseif slotName:find("Charm") ~= nil then
		return "flask" -- these don't have a unique string so overlapping mods of the same benefit could interfere. , "Charm"
	else
		return nil, nil
	end
end

return M