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