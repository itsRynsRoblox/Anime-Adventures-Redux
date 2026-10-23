#Requires AutoHotkey v2.0

DetectHuntMap() {
    AddToLog("Trying to determine map for Fool's Hunt...")
    startTime := A_TickCount

    loop {
        if (A_TickCount - startTime > 60000) {
            if (CheckForLobby()) {
                AddToLog("Found in lobby - restarting selected mode")
                return StartSelectedMode()
            }
            AddToLog("Could not detect map after 5 minutes - proceeding without movement")
            return "no map found"
        }

        ; Check for vote screen
        if (HasLoadedIn()) {
            AddToLog("No map found")
            return "no map found"
        }

        static loadingScreens := Map(
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

        CloseLeaderboard(false)

        for mapName, patterns in loadingScreens {
            try {
                for pattern in patterns {  ; Iterate through multiple images for each map
                    if (ok := ImageSearch(&X, &Y, 0, 0, A_ScreenWidth, A_ScreenHeight, "*15 " pattern)) {
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
    FreezeClientNew()
    AddToLog("Unfroze client")
    fixclick(200, 400)
    Sleep (1000)
    moveRobloxWindow()
    sleep 1000
    moveRobloxWindow()
}

GetMinimizeBtnPos(hwnd, &x, &y) {
    rect := Buffer(16)
    ; DWMWA_CAPTION_BUTTON_BOUNDS = 5 (min+max+close area, window-relative)
    if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 5, "ptr", rect, "uint", 16)
        return false
    l := NumGet(rect, 0, "int"), t := NumGet(rect, 4, "int")
    r := NumGet(rect, 8, "int"), b := NumGet(rect, 12, "int")
    x := Round(l + (r - l) / 6)   ; center of the first of 3 buttons = minimize
    y := Round((t + b) / 2)
    return true
}

FreezeClientNew(x := 692, y := 20, holdTime := 110000) {
    global rblxID
    hwnd := WinExist(rblxID)
    if !hwnd
        return false
    WinActivate(hwnd)
    if !WinWaitActive(hwnd, , 3)
        return false
    if GetMinimizeBtnPos(hwnd, &nx, &ny) {
        x := nx, y := ny
        ;AddToLog("Freeze: using computed minimize button position (" x "," y ")")
    } else {
      ;  AddToLog("Freeze: DWM lookup failed, using fallback position (" x "," y ")")
    }
    CoordMode("Mouse", "Window")
    MouseMove(x, y)
    Sleep(150)
    SendEvent("{RButton down}")
    Sleep(holdTime)
    SendEvent("{RButton up}")
    Sleep(50)
    CoordMode("Mouse", "Client")
    return true
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

    while (ok := FT(&X, &Y, 3, 548, 56, 594, 0, 0, LobbySettings)) {
        Sleep(500)
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