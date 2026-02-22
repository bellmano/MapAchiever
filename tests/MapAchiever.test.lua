describe("MapAchiever", function()

    -- -------------------------------------------------------------------------
    -- Per-test mutable state – reset in before_each so every test is isolated
    -- -------------------------------------------------------------------------
    local registeredCallbacks, frameScripts
    local loadedAddons, achievementFrameVisible, achievementFrameTab
    local tabClicked, searchCleared, searchString
    local filteredCount, filteredIds
    local achievementInfos, achievementStats, categoryParents
    local mockNameText, mockDescText, printed
    local updateHover, resetHover, onEvent

    before_each(function()
        registeredCallbacks    = {}
        frameScripts           = {}
        loadedAddons           = {}
        achievementFrameVisible = false
        achievementFrameTab    = 1
        tabClicked             = nil
        searchCleared          = 0
        searchString           = nil
        filteredCount          = 0
        filteredIds            = {}
        achievementInfos       = {}
        achievementStats       = {}
        categoryParents        = {}
        mockNameText           = ""
        mockDescText           = ""
        printed                = nil

        -- ---- WoW global stubs -----------------------------------------------
        -- Use _G explicitly so dofile'd code (which runs in _G) can see them.

        _G.WorldMapFrame = {
            ScrollContainer = {
                GetChildren = function()
                    local mockAreaText = {
                        Name = {
                            GetText = function() return mockNameText end,
                        },
                        Description = {
                            GetText  = function() return mockDescText end,
                            SetText  = function(_, txt) mockDescText = txt end,
                        },
                    }
                    -- childs[2] is areaText; returns nil as first value so
                    -- childs = {nil, mockAreaText} and childs[2] = mockAreaText
                    return nil, mockAreaText
                end,
            },
        }

        _G.EventRegistry = {
            RegisterCallback = function(_, event, fn)
                registeredCallbacks[event] = registeredCallbacks[event] or {}
                table.insert(registeredCallbacks[event], fn)
            end,
        }

        local mockEventFrame = {
            RegisterEvent = function() end,
            SetScript     = function(_, scriptType, fn)
                frameScripts[scriptType] = fn
            end,
        }
        _G.CreateFrame = function() return mockEventFrame end

        _G.C_AddOns = {
            IsAddOnLoaded = function(name) return loadedAddons[name] or false end,
            LoadAddOn     = function(name) loadedAddons[name] = true end,
        }

        _G.AchievementFrame = {
            IsVisible    = function() return achievementFrameVisible end,
            selectedTab  = achievementFrameTab,
        }

        _G.AchievementFrameTab_OnClick   = function(tab) tabClicked = tab end
        _G.ClearAchievementSearchString  = function() searchCleared = searchCleared + 1 end
        _G.SetAchievementSearchString    = function(str) searchString = str end

        -- RunNextFrame executes the callback immediately in tests
        _G.RunNextFrame = function(fn) fn() end

        _G.GetNumFilteredAchievements = function() return filteredCount end
        _G.GetFilteredAchievementID   = function(idx) return filteredIds[idx] or idx end
        _G.GetAchievementCategory     = function(aID) return aID end
        _G.GetCategoryInfo            = function(catID)
            return nil, categoryParents[catID] or 0
        end
        _G.GetAchievementInfo = function(aID)
            local info = achievementInfos[aID] or {}
            return nil, info.name or "Unnamed", nil, info.completed or false
        end
        _G.GetStatistic = function(aID) return achievementStats[aID] end

        _G.print = function(...) printed = table.concat({ tostring(select(1,...)), tostring(select(2,...)) }, " ") end

        -- ---- Load the addon fresh for each test ----------------------------
        dofile("MapAchiever/MapAchiever.lua")

        -- Extract the two callbacks registered for "MapLegendPinOnEnter"
        local cbs   = registeredCallbacks["MapLegendPinOnEnter"] or {}
        updateHover = cbs[1]   -- first registration = updateHover
        resetHover  = cbs[2]   -- second registration = resetHover
        onEvent     = frameScripts["OnEvent"]
    end)

    -- =========================================================================
    -- switchIfNot (called inside updateHover → RunNextFrame closure)
    -- =========================================================================
    describe("switchIfNot", function()

        it("loads the addon and clicks tab 3 when not loaded and frame is hidden", function()
            loadedAddons["Blizzard_AchievementUI"] = false
            achievementFrameVisible = false
            _G.AchievementFrame.selectedTab = 1

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Test", journalInstanceID = 1 })

            assert.is_true(loadedAddons["Blizzard_AchievementUI"])
            assert.equal(3, tabClicked)
        end)

        it("skips LoadAddOn when addon is already loaded", function()
            loadedAddons["Blizzard_AchievementUI"] = true
            achievementFrameVisible = true   -- also skip tab click

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "T", journalInstanceID = 1 })

            -- LoadAddOn was not called – value stays true but tabClicked stays nil
            assert.is_nil(tabClicked)
        end)

        it("skips tab click when selectedTab is already 3", function()
            loadedAddons["Blizzard_AchievementUI"] = false
            achievementFrameVisible = false
            _G.AchievementFrame.selectedTab = 3

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "T", journalInstanceID = 1 })

            assert.is_nil(tabClicked)
        end)

    end)

    -- =========================================================================
    -- updateHover
    -- =========================================================================
    describe("updateHover", function()

        it("starts a search with the pin name for dungeon entrance pins", function()
            mockNameText = "Test Dungeon"
            mockDescText = ""

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Test Dungeon", journalInstanceID = 1 })

            assert.equal(1, searchCleared)
            assert.equal("Test Dungeon", searchString)
        end)

        it("uses the exceptions table entry when journalInstanceID matches", function()
            -- ID 758 maps to "Icecrown" in the exceptions table
            -- mockNameText must be non-empty so the last==name..desc guard is not hit
            mockNameText = "Icecrown Citadel"
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Icecrown Citadel", journalInstanceID = 758 })

            assert.equal("Icecrown", searchString)
        end)

        it("does not start a search for non-dungeon pins", function()
            -- Non-empty name ensures we reach line 48 (the pin template check) rather
            -- than returning early at the last==name..desc guard.
            mockNameText = "Map Location"
            updateHover(nil, { pinTemplate = "SomeOtherPinTemplate", name = "Other" })

            assert.is_nil(searchString)
        end)

        it("returns early without a new search when name+desc has not changed", function()
            mockNameText = "Same"
            mockDescText = "Desc"

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Same", journalInstanceID = 1 })
            searchString = nil  -- reset to detect whether another search fires

            -- Second call with identical name+desc → early return
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Same", journalInstanceID = 1 })
            assert.is_nil(searchString)
        end)

        it("does nothing extra when pin argument is nil", function()
            -- Non-empty name ensures we reach the pin nil-check on line 48.
            mockNameText = "Test"
            updateHover(nil, nil)

            assert.is_nil(searchString)
        end)

    end)

    -- =========================================================================
    -- resetHover
    -- =========================================================================
    describe("resetHover", function()

        it("resets 'last' so updateHover processes the same content again", function()
            mockNameText = "Dungeon"
            mockDescText = ""

            -- First call caches the content; second would return early without reset
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dungeon", journalInstanceID = 1 })
            searchString = nil

            resetHover()

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dungeon", journalInstanceID = 1 })
            assert.is_not_nil(searchString)
        end)

    end)

    -- =========================================================================
    -- OnEvent
    -- =========================================================================
    describe("OnEvent", function()

        it("returns immediately when waitForSearch is nil", function()
            -- No updateHover call → waitForSearch stays nil
            assert.has_no_error(function() onEvent() end)
            assert.equal("", mockDescText)
        end)

        it("handles ej=1209 (Dawn of the Infinite) when both achievements are done", function()
            achievementInfos[18703] = { completed = true }
            achievementInfos[18704] = { completed = true }
            mockNameText = "Dawn of the Infinite"
            mockDescText = ""

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dawn of the Infinite", journalInstanceID = 1209 })
            onEvent()

            -- Description should contain both wing labels
            assert.truthy(mockDescText:find("Galakrond"))
            assert.truthy(mockDescText:find("Murozond"))
        end)

        it("handles ej=1209 when both achievements are not done", function()
            achievementInfos[18703] = { completed = false }
            achievementInfos[18704] = { completed = false }
            mockNameText = "Dawn of the Infinite"
            mockDescText = ""

            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dawn of the Infinite", journalInstanceID = 1209 })
            onEvent()

            assert.truthy(mockDescText:find("Galakrond"))
        end)

        it("does not update desc when pin name has changed before OnEvent fires", function()
            mockNameText = "Old Name"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Old Name", journalInstanceID = 1 })

            -- Simulate name changing (e.g. player moved mouse) before OnEvent fires
            mockNameText = "New Name"
            filteredCount = 1
            filteredIds   = { 1 }
            categoryParents[1]  = 14807
            achievementInfos[1] = { name = "Old Name (Heroic)" }
            achievementStats[1] = 5

            onEvent()

            assert.equal("", mockDescText)  -- unchanged
        end)

        it("does not update desc when pDesc was non-empty and changed before OnEvent fires", function()
            mockNameText = "Dungeon"
            mockDescText = "OriginalDesc"
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dungeon", journalInstanceID = 1 })

            -- desc changes before OnEvent fires → sameDesc = false
            mockDescText = "ChangedDesc"
            filteredCount = 1
            filteredIds   = { 5 }
            categoryParents[5]  = 14807
            achievementInfos[5] = { name = "Dungeon (Normal)" }
            achievementStats[5] = 3

            onEvent()

            assert.equal("ChangedDesc", mockDescText)  -- unchanged
        end)

        it("treats empty pDesc as sameDesc=true (no pDesc check)", function()
            mockNameText = "Dungeon"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dungeon", journalInstanceID = 1 })

            filteredCount = 1
            filteredIds   = { 7 }
            categoryParents[7]  = 14807
            achievementInfos[7] = { name = "Dungeon (Normal)" }
            achievementStats[7] = 10

            onEvent()

            assert.truthy(mockDescText:find("Normal"))
        end)

        it("writes difficulty and done-mark for a single achievement", function()
            mockNameText = "Test Dungeon"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Test Dungeon", journalInstanceID = 1 })

            filteredCount = 1
            filteredIds   = { 42 }
            categoryParents[42]  = 14807
            achievementInfos[42] = { name = "Test Dungeon (Heroic)" }
            achievementStats[42] = 7

            onEvent()

            assert.truthy(mockDescText:find("Heroic"))
        end)

        it("skips achievements whose parent category is not 14807", function()
            mockNameText = "Test"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Test", journalInstanceID = 1 })

            filteredCount = 1
            filteredIds   = { 10 }
            categoryParents[10]  = 999   -- wrong parent
            achievementInfos[10] = { name = "Something" }

            onEvent()

            assert.equal("", mockDescText)
        end)

        it("marks achievement as not-done when statistic is nil", function()
            mockNameText = "Raid"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Raid", journalInstanceID = 2 })

            filteredCount = 1
            filteredIds   = { 20 }
            categoryParents[20]  = 14807
            achievementInfos[20] = { name = "Raid (Mythic)" }
            achievementStats[20] = nil   -- not completed

            onEvent()

            assert.truthy(mockDescText:find("Mythic"))
        end)

        it("falls back to '?' diff label when achievement name has no parentheses", function()
            mockNameText = "Place"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Place", journalInstanceID = 3 })

            filteredCount = 1
            filteredIds   = { 30 }
            categoryParents[30]  = 14807
            achievementInfos[30] = { name = "No parens achievement" }
            achievementStats[30] = 3

            onEvent()

            assert.truthy(mockDescText:find("%?"))
        end)

        it("keeps NOTDONE when NOTDONE diff appears again with a stat value (override)", function()
            -- Two achievements with the same diff label: first has no stat (NOTDONE),
            -- second has a stat but that must not upgrade it back to DONE.
            mockNameText = "Dungeon"
            mockDescText = ""
            updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Dungeon", journalInstanceID = 4 })

            filteredCount = 2
            filteredIds   = { 40, 41 }
            categoryParents[40]  = 14807
            categoryParents[41]  = 14807
            achievementInfos[40] = { name = "Dungeon (Heroic)" }
            achievementInfos[41] = { name = "Dungeon (Heroic)" }
            achievementStats[40] = nil   -- not done → NOTDONE first
            achievementStats[41] = 5    -- done, but first slot was NOTDONE → stays NOTDONE

            onEvent()

            assert.truthy(mockDescText:find("Heroic"))
        end)

        -- -----------------------------------------------------------------
        -- Word-splitting path (resultNum < 1 or >= 100)
        -- -----------------------------------------------------------------
        describe("word splitting", function()

            it("searches each word of the pin name in turn when filters return nothing", function()
                mockNameText = "Black Rook Hold"
                mockDescText = ""
                updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Black Rook Hold", journalInstanceID = 5 })

                filteredCount = 0   -- triggers word splitting

                onEvent()
                assert.equal("Black", searchString)

                onEvent()
                assert.equal("Rook", searchString)

                onEvent()
                assert.equal("Hold", searchString)
            end)

            it("prints a message when all individual words have been tried", function()
                mockNameText = "X"
                mockDescText = ""
                updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "X", journalInstanceID = 6 })

                filteredCount = 0

                onEvent()   -- searches "X", wIndex becomes 2
                onEvent()   -- wIndex > #words → prints

                assert.truthy(printed and printed:find("Tried all"))
            end)

            it("enters the word-splitting path when resultNum >= 100", function()
                mockNameText = "Test"
                mockDescText = ""
                updateHover(nil, { pinTemplate = "DungeonEntrancePinTemplate", name = "Test", journalInstanceID = 7 })

                filteredCount = 100   -- >= 100 also triggers word splitting

                onEvent()

                assert.equal("Test", searchString)
            end)

        end)

    end)

end)
