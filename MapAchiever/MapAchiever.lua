local childs = { WorldMapFrame.ScrollContainer:GetChildren() }
local areaText = childs[2]
local last = ""
local exceptions = {
	[758] = "Icecrown",
	[280] = "Forge of Souls",
	[249] = "Magister's Terrace",
	[237] = "Sunken Temple",
	[740] = "Black Rook Hold",
	[1041] = "King's Rest",
	[749] = "Tempest Keep",
	[250] = "Mana Tombs",
	[753] = "Wintergrasp",
	[756] = "Malygos",
	[755] = "Chamber of the Aspects",
	[761] = "Ruby Sanctum",
}
local DONE, NOTDONE = "|A:common-icon-checkmark:16:16|a", "|A:common-icon-redx:16:16|a"
local waitForSearch

local function splitStr(str)
	local words = {}
	for word in str:gmatch("%S+") do
		table.insert(words, word)
	end
	return words
end

local function startSearch(str)
	ClearAchievementSearchString()
	SetAchievementSearchString(str)
end
local function switchIfNot()
	if not C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
		C_AddOns.LoadAddOn("Blizzard_AchievementUI")
	end
	if not AchievementFrame:IsVisible() and AchievementFrame.selectedTab ~= 3 then
		AchievementFrameTab_OnClick(3)
		--SwitchAchievementSearchTab(3)
	end
end
local function updateHover(_, pin)
	RunNextFrame(function()
		switchIfNot()
		local name = areaText.Name:GetText() or ""
		local desc = areaText.Description:GetText() or ""
		if last == name .. desc then
			return
		end
		last = name .. desc
		if pin and pin.pinTemplate and pin.pinTemplate == "DungeonEntrancePinTemplate" then
			--print(EJ_GetInstanceInfo(pin.journalInstanceID))
			waitForSearch = {
				name = pin.name,
				frame = areaText,
				pName = name,
				pDesc = desc,
				ej = pin.journalInstanceID,
			}
			startSearch(exceptions[pin.journalInstanceID] or name)
		end
	end)
end

local function resetHover()
	last = ""
end

EventRegistry:RegisterCallback("MapLegendPinOnEnter", updateHover)
EventRegistry:RegisterCallback("MapLegendPinOnEnter", resetHover)

local function OnEvent()
	if not waitForSearch then
		return
	end
	local data = waitForSearch
	local name = data.frame.Name
	local desc = data.frame.Description

	if data.ej == 1209 then
		local fC = select(4, GetAchievementInfo(18703)) and DONE or NOTDONE
		local rC = select(4, GetAchievementInfo(18704)) and DONE or NOTDONE
		desc:SetText(string.format("Galakrond's Fall: %s\nMurozond's Rise: %s", fC, rC))
		return
	end

	local sameDesc = data.pDesc and desc:GetText() == data.pDesc
	if not data.pDesc or data.pDesc == "" then
		sameDesc = true
	end

	if name:GetText() == data.pName and sameDesc then
		local tbl = {}
		local resultNum = GetNumFilteredAchievements()
		if resultNum < 1 or resultNum >= 100 then
			if not data.words then
				data.words = splitStr(data.pName)
				data.wIndex = 1
			end
			if data.wIndex <= #data.words then
				local newSearch = data.words[data.wIndex]
				data.wIndex = data.wIndex + 1
				startSearch(newSearch)
				--print("retry search with:", newSearch, "Instance:", data.ej)
			else
				print("Tried all name combinations instance:", data.ej)
			end
			return
		end
		for idx = 1, resultNum do
			local aID = GetFilteredAchievementID(idx)
			local pCat = select(2, GetCategoryInfo(GetAchievementCategory(aID)))

			if pCat == 14807 then
				local _, aName = GetAchievementInfo(aID)
				local count = GetStatistic(aID)
				local pattern = string.format("%%((.+)%s%%)", data.pName)
				local diff = string.match(aName, pattern) or string.match(aName, "%((.+)%)") or "?"
				local check = tonumber(count)
				if tbl[diff] then
					if tbl[diff] == NOTDONE and check then
						check = false
					end
				end
				tbl[diff] = check and DONE or NOTDONE
			end
		end
		local txt = ""
		for diff, check in pairs(tbl) do
			txt = string.format("%s%s %s\n", txt, diff, check)
		end
		desc:SetText(txt)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ACHIEVEMENT_SEARCH_UPDATED")
f:SetScript("OnEvent", OnEvent)
