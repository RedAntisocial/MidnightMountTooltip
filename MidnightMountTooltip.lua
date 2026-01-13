--[[ See README.md for overview of the project. ]]--

--[[
  Blizzard wraps all of our code in a function, which is passed two arguments.
  These arguments can be accessed through the elipses shorthand,
  The first variable is a string containing the name of our addon.
  The second is a table whose scope is limited to this addon
  (or the function blizzard implements as the addon).
  This table is the same across files in the addon, and is a simple way to
  share data across files without relying on a global namespace.
]]--
local addonName, MidnightMountTooltip = ...;

--[[
  This function look at player auras to find one which matches a mount.
  Gets called from MountTooltip.ProcessAuras, which cycles through this for
  each aura it finds.

  See https://wowpedia.fandom.com/wiki/API_C_UnitAuras.GetAuraDataByIndex
]]--
function MidnightMountTooltip.CheckAurasForMount(auraData)
  -- early exit if no aura data
  if not auraData then
    return false;
  end

  -- mountIds are their own thing
  -- See https://wowpedia.fandom.com/wiki/MountID
  local mountID = C_MountJournal.GetMountFromSpell(auraData.spellId);

  -- if we found a mount from a spellID, then add it to the tooltip and exit
  if (mountID ~= nil) then

    -- get mount information
    local mount = MidnightMountTooltip.Mount:new();
    local foundMountInfo = mount:getMountInfo(mountID);

    -- make sure we actually found the mount information
    if (not foundMountInfo) then
      return true;
    end

    -- simple blank line for formatting
    GameTooltip:AddLine(" ");

    -- formulate the icon string for text processing, ending space is important
    -- See https://wowpedia.fandom.com/wiki/UI_escape_sequences
    local iconString = "|T" .. mount.icon .. ":25" .. "|t ";

    -- add collection status
    local collectionText;
    local collectionColor;
    if mount.isCollected then
      collectionText = "Collected";
      collectionColor = "|cff0070dd"; -- blue
    else
      collectionText = "Not Collected";
      collectionColor = "|cff9d0000"; -- dark red
    end
	
	-- add mount info to the tooltip
    GameTooltip:AddLine(iconString .. mount.name .. " - " .. collectionColor .. collectionText .. "|r");

    -- breaks the loop because our function returns a value
    return true;
   end
end

-- called when the unit tooltip event is fired
function MidnightMountTooltip.ProcessAuras(self)
  -- exit early if in combat, so we don't breaks the secrets!!! shhhh!
  if InCombatLockdown() then
    return;
  end

   local name, unit = self:GetUnit();

  -- ! Early Return
  -- exit early if the unit is nil or false
  if not unit then
    return;
  end

  -- check if unit is a player, use a protected call in case unit is secret (like an NPC in a dungeon)
  local isPlayer = false;
  local success, result = pcall(UnitIsPlayer, unit);
  if success then
    isPlayer = result;
  end

  -- exit if not a player
  if not isPlayer then
    return;
  end

  --[[ Cycle through each aura and check for a mount.
    Updated to use C_UnitAuras.GetAuraDataByIndex as of patch 12.0.0
    The 40 number here is the max number of auras to check that we set.
    This may not be necessary, but its here to limit how much procesing we do
    so we don't get stuck doing a lot of stuff.
    Theres no error reporting or way to show the user what happened if the
    player had too many buffs but indeed did have a mount.

    See https://wowpedia.fandom.com/wiki/API_C_UnitAuras.GetAuraDataByIndex
  ]]
  for i = 1, 40 do
    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL");
    
    -- stop if no more auras
    if not auraData then
      break;
    end
    
    -- check if this aura is a mount
    if MidnightMountTooltip.CheckAurasForMount(auraData) then
      break;
    end
  end

  -- we dont really need a return value, this feels bad =(
  -- probably need to look at GameTooltip:HookScript for return values
end

-- hook into the tooltip event, which fires on specific mousovers,
-- with our own function MidnightMountTooltip.ProcessAuras

-- new funtion for accessing this event
TooltipDataProcessor.AddTooltipPostCall(
  Enum.TooltipDataType.Unit, MidnightMountTooltip.ProcessAuras
);