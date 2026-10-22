#Requires AutoHotkey v2.0

DetectHuntMap() {
    AddToLog("Trying to determine map for Fool's Hunt...")
    startTime := A_TickCount

    loop {
        ; Check if we waited more than 5 minute for votestart
        if (A_TickCount - startTime > 300000) {
            if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                AddToLog("Found in lobby - restarting selected mode")
                return StartSelectedMode
            }
            AddToLog("Could not detect map after 5 minutes - proceeding without movement")
            return "no map found"
        }

        ; Check for vote screen
        if (ok := FT(&X, &Y, 326, 60, 547, 173, 0, 0, VoteStart) or (ok := FT(&X, &Y, 340, 537, 468, 557, 0, 0, Yen))) {
            AddToLog("No Map Found or Movement Unnecessary")
            return "no map found"
        }

        loadingScreens := Map(
            ; Story Maps
            "Planet Greenie", [PlanetGreenieLoadingScreen],
            "Walled City", [WalledCityLoadingScreen],
            "Snowy Town", [SnowyTownLoadingScreen],  ; Example of multiple images
            "Sand Village", [SandVillageLoadingScreen],
            "Navy Bay", [NavyBayLoadingScreen],
            "Fiend City", [FiendCityLoadingScreen],
            "Spirit World", [SpiritWorldLoadingScreen],
            "Ant Kingdom", [AntKingdomLoadingScreen, AntKingdomLoadingScreen2, AntKingdomLoadingScreen3, AntKingdomRaidLoadingScreen],
            "Magic Town", [MagicTownLoadingScreen],
            "Magic Hills", [MagicHillsLoadingScreen],
            "Haunted Academy", [HauntedAcademyLoadingScreen],
            "Alien Spaceship", [AlienSpaceshipLoadingScreen],
            "Space Center", [SpaceCenterLoadingScreen],
            "Fabled Kingdom", [FabledKingdomLoadingScreen, FabledKingdomLoadingScreen2, FabledKingdomLoadingScreen3, FabledKingdomLoadingScreen4],
            "Ruined City", [RuinedCityLoadingScreen],
            "Puppet Island", [PuppetIslandLoadingScreen],
            "Virtual Dungeon", [VirtualDungeonLoadingScreen],
            "Snowy Kingdom", [SnowyKingdomLoadingScreen],
            "Dungeon Throne", [DungeonThroneLoadingScreen],
            "Mountain Temple", [MountainTempleLoadingScreen],
            "Rain Village", [RainVillageLoadingScreen],
            "Shibuya District", [ShibuyaDistrictLoadingScreen],
            ; Legend Stages
            "Spirit Town", [SpiritTownLoadingScreen],
            ; Raids
            "Sacred Planet", [SacredPlanetLoadingScreen],
            "Strange Town", [StrangeTownLoadingScreen],
            "Cursed Festival", [CursedFestivalLoadingScreen],
            "Storm Hideout", [StormHideoutLoadingScreen],
            "Nightmare Train", [NightmareTrainLoadingScreen],
            "Future City", [FutureCityLoadingScreen],
            ; Event Maps
            "Assassin Park", [AssassinParkLoadingScreen],
            "Haunted Mansion", [HauntedMansionLoadingScreen],
            ; Unfinished Maps
            "Air Craft", [AirCraftLoadingScreen],
            "Hellish City", [HellishCityLoadingScreen]
        )

        for mapName, patterns in loadingScreens {
            try {
                for pattern in patterns {  ; Iterate through multiple images for each map
                    if (ok := ImageSearch(&X, &Y, 3, 4, 796, 593, "*15 " pattern)) {
                        AddToLog("Detected Map: " mapName)
                        return mapName
                    }
                }
            } catch {
                if (debugMessages) {
                    AddToLog("Error occurred during map detection.")
                }
            }
        }

        Sleep 1000
        Reconnect()
    }
}

ClickAndHoldExit() {
    if WinExist(rblxID) {
        WinMove(-10, 15, 800, 600, rblxID)
        WinActivate(rblxID)
        Sleep 1000
    }
    AddToLog("Freezing client for 2 minutes...")
    FreezeClientNew(692, 20) ; Freeze Client for 2 minutes before resuming
    AddToLog("Unfroze client")
    fixclick(200, 400)
    Sleep (1000)
    moveRobloxWindow()
    sleep 1000
    moveRobloxWindow()
}

FreezeClientNew(x, y, holdTime := 110000) { ;110000
    CoordMode("Mouse", "Window")
    MouseMove(x, y)                     ; move to Roblox minimize button
    Sleep(50)
    SendEvent("{RButton down}")         ; hold right click
    Sleep(holdTime)                     ; 2 minutes = 120000 ms
    SendEvent("{RButton up}")           ; release
    Sleep(50)
    CoordMode("Mouse", "Client")
}

StartFoolsHunt() {
    ; Execute the movement pattern
    AddToLog("Moving to position for Fool's Hunt")
    EventMovement()

    ; Start stage
    while !(ok := FT(&X, &Y, 468 - 150000, 386 - 150000, 468 + 150000, 386 + 150000, 0, 0, JoinMatchmaking)) {
        Reconnect() ; Added Disconnect Check
        EventMovement()
    }

    ; Handle play mode selection
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }

    AddToLog("Starting Fool's Hunt")
    RestartStage()
}

EventMovement() {
    FixClick(592, 204) ; Close Matchmaking UI (Just in case)
    Sleep (200)
    FixClick(85, 295) ; Click Play
    sleep (1000)
    SendInput ("{a up}")
    Sleep 100
    SendInput ("{a down}")
    Sleep 6000
    SendInput ("{a up}")
    KeyWait "a" ; Wait for "d" to be fully processed
    Sleep 1200
}

CheckForFoolBuffs() {
    CheckForRandomBuff()
    CheckForAstralGate()
    CheckForAstralSummon()
    CheckForClone()
    CheckForMerge()
    CheckForRefund()
}

CheckForRandomBuff() {
    global successfulCoordinates, maxedCoordinates
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.35, 0.35, RandomBuff)) {
        ; Prefer maxedCoordinates
        if maxedCoordinates.Length > 0 {
            randomIndex := Random(1, maxedCoordinates.Length)
            coord := maxedCoordinates[randomIndex]

            AddToLog("Found random buff, applying to maxed unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }

        ; Otherwise use successfulCoordinates
        else if successfulCoordinates.Length > 0 {
            randomIndex := Random(1, successfulCoordinates.Length)
            coord := successfulCoordinates[randomIndex]

            AddToLog("Found random buff, applying to random unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }
    }
    return false
}

CheckForClone() {
    global successfulCoordinates, maxedCoordinates
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.25, 0.25, Clone)) {
        ; Prefer maxedCoordinates
        if maxedCoordinates.Length > 0 {
            randomIndex := Random(1, maxedCoordinates.Length)
            coord := maxedCoordinates[randomIndex]

            AddToLog("Found clone, applying to maxed unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }
        ; Otherwise use successfulCoordinates
        else if successfulCoordinates.Length > 0 {
            randomIndex := Random(1, successfulCoordinates.Length)
            coord := successfulCoordinates[randomIndex]

            AddToLog("Found clone, applying to random unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }
    }
    return false
}

CheckForMerge() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.25, 0.25, Merge)) {
        AddToLog("Found merge, deleting buff...")
        FixClick(X + 15, Y - 45)
        Sleep(500)
        Sleep(250)
        return true
    }
    return false
}

CheckForRefund() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.25, 0.25, Refund)) {
        AddToLog("Found refund, deleting buff...")
        FixClick(X + 15, Y - 45)
        Sleep(500)
        return true
    }
    return false
}

CheckForAstralGate() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.35, 0.35, AstralGate)) {
        AddToLog("Found astral gate, attempting to use...")
        FTClick(X, Y)
        Sleep(500)
        return true
    }
    return false
}

CheckForAstralSummon() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.30, 0.30, AstralSummon)) {
        AddToLog("Found astral summon, attempting to use...")
        FTClick(X, Y)
        Sleep(500)
        return true
    }
    return false
}