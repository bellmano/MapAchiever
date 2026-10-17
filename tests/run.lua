local testsRun = 0
local failures = {}
local originalPrint = print

local function test(name, callback)
	testsRun = testsRun + 1
	local ok, err = pcall(callback)
	if not ok then
		failures[#failures + 1] = name .. ": " .. tostring(err)
	end
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertContains(value, expected, message)
	if not value:find(expected, 1, true) then
		error((message or "text does not contain expected value") .. ": " .. expected, 2)
	end
end

local function newHarness(options)
	options = options or {}
	local state = {
		loaded = options.loaded or false,
		visible = options.visible or false,
		selectedTab = options.selectedTab or 1,
		achievementInfo = options.achievementInfo or {},
		categories = options.categories or {},
		parentCategories = options.parentCategories or {},
		statistics = options.statistics or {},
		filteredIds = options.filteredIds or {},
		filteredCount = options.filteredCount or 0,
		callbacks = {},
		nextFrame = {},
		searches = {},
		prints = {},
		loadCalls = 0,
		tabClicks = 0,
	}

	local function makeText(initialText)
		return {
			text = initialText,
			GetText = function(self)
				return self.text
			end,
			SetText = function(self, text)
				self.text = text
			end,
		}
	end

	local area = {
		Name = makeText(options.name or "Test Dungeon"),
		Description = makeText(options.description or "Description"),
	}

	_G.WorldMapFrame = {
		ScrollContainer = {
			GetChildren = function()
				return {}, area
			end,
		},
	}
	_G.C_AddOns = {
		IsAddOnLoaded = function()
			return state.loaded
		end,
		LoadAddOn = function()
			state.loadCalls = state.loadCalls + 1
			state.loaded = true
		end,
	}
	_G.AchievementFrame = {
		IsVisible = function()
			return state.visible
		end,
		selectedTab = state.selectedTab,
	}
	_G.AchievementFrameTab_OnClick = function(tab)
		state.tabClicks = state.tabClicks + 1
		state.selectedTab = tab
	end
	_G.EventRegistry = {
		RegisterCallback = function(_, _, callback)
			state.callbacks[#state.callbacks + 1] = callback
		end,
	}
	_G.RunNextFrame = function(callback)
		state.nextFrame[#state.nextFrame + 1] = callback
	end
	_G.ClearAchievementSearchString = function()
		state.searches[#state.searches + 1] = false
	end
	_G.SetAchievementSearchString = function(search)
		state.searches[#state.searches + 1] = search
	end
	_G.GetAchievementInfo = function(achievementId)
		local achievement = state.achievementInfo[achievementId] or {}
		return nil, achievement.name, nil, achievement.completed
	end
	_G.GetNumFilteredAchievements = function()
		return state.filteredCount
	end
	_G.GetFilteredAchievementID = function(index)
		return state.filteredIds[index]
	end
	_G.GetAchievementCategory = function(achievementId)
		return state.categories[achievementId]
	end
	_G.GetCategoryInfo = function(categoryId)
		return nil, state.parentCategories[categoryId] or 14807
	end
	_G.GetStatistic = function(achievementId)
		return state.statistics[achievementId]
	end
	_G.print = function(...)
		state.prints[#state.prints + 1] = table.concat({ ... }, " ")
	end
	_G.CreateFrame = function()
		local frame = {}
		function frame:RegisterEvent(event)
			state.event = event
		end
		function frame:SetScript(_, callback)
			state.onEvent = callback
		end
		return frame
	end

	dofile("MapAchiever/MapAchiever.lua")

	local harness = {
		state = state,
		name = area.Name,
		description = area.Description,
	}

	function harness.flushFrames()
		local index = 1
		while index <= #state.nextFrame do
			local callback = state.nextFrame[index]
			index = index + 1
			callback()
		end
		state.nextFrame = {}
	end

	function harness.hover(pin)
		for _, callback in ipairs(state.callbacks) do
			callback(nil, pin)
		end
		harness.flushFrames()
	end

	function harness.fireEvent()
		state.onEvent()
	end

	return harness
end

local dungeonPin = {
	pinTemplate = "DungeonEntrancePinTemplate",
	name = "Test Dungeon",
	journalInstanceID = 999,
}

test("loads achievements and searches for a dungeon pin", function()
	local h = newHarness({ selectedTab = 1 })
	h.hover(dungeonPin)
	assertEqual(h.state.event, "ACHIEVEMENT_SEARCH_UPDATED")
	assertEqual(h.state.loadCalls, 1)
	assertEqual(h.state.tabClicks, 1)
	assertEqual(h.state.searches[2], "Test Dungeon")
end)

test("uses exception names, honors loaded state, and skips non-dungeon pins", function()
	local h = newHarness({ loaded = true, visible = true })
	local pin = {
		pinTemplate = "DungeonEntrancePinTemplate",
		name = "Wrong Name",
		journalInstanceID = 758,
	}
	h.hover(pin)
	assertEqual(h.state.searches[2], "Icecrown")
	assertEqual(h.state.loadCalls, 0)
	assertEqual(h.state.tabClicks, 0)

	local searches = #h.state.searches
	h.hover({ pinTemplate = "OtherPinTemplate" })
	assertEqual(#h.state.searches, searches)
end)

test("does not switch tabs when the achievement frame is already on tab three", function()
	local h = newHarness({ loaded = true, selectedTab = 3 })
	h.hover(dungeonPin)
	assertEqual(h.state.tabClicks, 0)
end)

test("avoids repeating an unchanged deferred hover update", function()
	local h = newHarness({ loaded = true, visible = true })
	local updateHover = h.state.callbacks[1]
	updateHover(nil, dungeonPin)
	h.flushFrames()
	updateHover(nil, dungeonPin)
	h.flushFrames()
	assertEqual(#h.state.searches, 2)
end)

test("ignores achievement events before a dungeon search is pending", function()
	local h = newHarness()
	h.fireEvent()
	assertEqual(#h.state.searches, 0)
end)

test("shows both achievement statuses for Galakrond's Fall and Murozond's Rise", function()
	local h = newHarness({
		achievementInfo = {
			[18703] = { completed = true },
			[18704] = { completed = false },
		},
	})
	h.hover({
		pinTemplate = "DungeonEntrancePinTemplate",
		name = "Dawn of the Infinite",
		journalInstanceID = 1209,
	})
	h.fireEvent()
	assertContains(h.description.text, "Galakrond's Fall:")
	assertContains(h.description.text, "|A:common-icon-checkmark:16:16|a")
	assertContains(h.description.text, "|A:common-icon-redx:16:16|a")
end)

test("shows incomplete statuses when neither special achievement is complete", function()
	local h = newHarness()
	h.hover({
		pinTemplate = "DungeonEntrancePinTemplate",
		name = "Dawn of the Infinite",
		journalInstanceID = 1209,
	})
	h.fireEvent()
	assertEqual(
		h.description.text,
		"Galakrond's Fall: |A:common-icon-redx:16:16|a\nMurozond's Rise: |A:common-icon-redx:16:16|a"
	)
end)

test("does not replace details after the hovered name changes", function()
	local h = newHarness()
	h.hover(dungeonPin)
	h.name:SetText("Another Dungeon")
	h.state.filteredCount = 1
	h.fireEvent()
	assertEqual(h.description.text, "Description")
end)

test("does not replace details after the hovered description changes", function()
	local h = newHarness()
	h.hover(dungeonPin)
	h.description:SetText("Updated description")
	h.state.filteredCount = 1
	h.fireEvent()
	assertEqual(h.description.text, "Updated description")
end)

test("allows achievement results when the hovered description is empty", function()
	local h = newHarness({ name = "Alpha Beta", description = "", filteredCount = 0 })
	h.hover(dungeonPin)
	h.fireEvent()
	assertEqual(h.state.searches[#h.state.searches], "Alpha")
end)

test("retries each name word and reports when all search combinations are exhausted", function()
	local h = newHarness({ name = "Alpha Beta", filteredCount = 0 })
	h.hover(dungeonPin)
	h.fireEvent()
	assertEqual(h.state.searches[#h.state.searches], "Alpha")

	h.state.filteredCount = 100
	h.fireEvent()
	assertEqual(h.state.searches[#h.state.searches], "Beta")
	h.fireEvent()
	assertEqual(#h.state.prints, 1)
	assertContains(h.state.prints[1], "999")
end)

test("uses the first matching achievement set and formats difficulty results", function()
	local h = newHarness({
		filteredCount = 7,
		filteredIds = { 101, 102, 103, 104, 105, 106, 107 },
		categories = {
			[101] = 1,
			[102] = 1,
			[103] = 1,
			[104] = 1,
			[105] = 1,
			[106] = 1,
			[107] = 1,
		},
		parentCategories = {
			[2] = 1,
		},
		statistics = {
			[102] = "1",
			[103] = "1",
			[105] = "0",
		},
	})
	h.state.categories[107] = 2
	h.state.achievementInfo = {
		[101] = { name = "Achievement (Mythic Test Dungeon)" },
		[102] = { name = "Another (Mythic Test Dungeon)" },
		[103] = { name = "Achievement (Heroic)" },
		[104] = { name = "Another (Heroic)" },
		[105] = { name = "Achievement without a difficulty" },
		[106] = { name = "Achievement with no count (Normal)" },
		[107] = { name = "Excluded category (Other)" },
	}
	h.hover(dungeonPin)
	h.state.statistics[106] = nil
	h.fireEvent()
	assertContains(h.description.text, "Mythic")
	assertContains(h.description.text, "Heroic")
	assertContains(h.description.text, "Normal")
	assertContains(h.description.text, "?")
	assertContains(h.description.text, "|A:common-icon-checkmark:16:16|a")
	assertContains(h.description.text, "|A:common-icon-redx:16:16|a")
end)

if #failures > 0 then
	for _, failure in ipairs(failures) do
		io.stderr:write("FAIL: ", failure, "\n")
	end
	error(string.format("%d of %d tests failed", #failures, testsRun), 0)
end

originalPrint(string.format("OK: %d tests passed", testsRun))
