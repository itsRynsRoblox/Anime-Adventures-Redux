#Requires AutoHotkey v2.0
#Include %A_ScriptDir%/lib/Tools/Image.ahk
global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global cachedCardPriorities := Map()
LoadKeybindSettings()  ; Load saved keybinds
CheckForUpdates()
StartRapidOcr()
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())

F5:: {
    SetRegion()
}

F6:: {

}

F7:: {
    CopyMouseCoords(true)
}

F8:: {
    Run (A_ScriptDir "\Lib\Tools\FindText.ahk")
}

F9:: {
    OpenDebugMenu()
}

StartMacro(*) {
    if (!ValidateMode()) {
        return
    }
    if (StartsInLobby(ModeDropdown.Text) || StartsInLobby(EventDropdown.Text)) {
        if (CheckForLobby()) {
            StartSelectedMode()
        } else {
            AddToLog("You need to be in the lobby to start " ModeDropdown.Text)
        }
    } else {
        StartSelectedMode()
    }
}

TogglePause(*) {
    Pause -1
    if (A_IsPaused) {
        AddToLog("Macro Paused")
        Sleep(1000)
    } else {
        AddToLog("Macro Resumed")
        Sleep(1000)
    }
}

CheckForXP(closeLeaderboard := false) {
    if (closeLeaderboard) {
        FixClick(564, 72)
        Sleep(1200)
    }
    ; Check for lobby text
    if (ok := FT(&X, &Y, 575, 145, 641, 210, 0, 0, XpText)) {
        FixClick(325, 185)
        FixClick(560, 560)
        return true
    }
    return false
}

ChallengeMode() {    
    AddToLog("Moving to Challenge mode")
    ChallengeMovement()
    
    while !(ok := FindText(&X, &Y, 325, 520, 489, 587, 0, 0, Story)) {
        ChallengeMovement()
    }

    RestartStage()
}

CustomMode() {
    AddToLog("Starting Custom Mode")
    RestartStage()
}

HandleEndScreen(isVictory := true) {
    Switch ModeDropdown.Text {
        Case "Story":
            HandleStoryEnd()
        Case "Portal":
            HandlePortalEnd(isVictory)
        case "Custom":
            HandleCustomEnd()    
        Default:
            HandleDefaultEnd()
    }
}

HandleStoryEnd() {
    global lastResult
    AddToLog("Handling Story mode end")
    if (NextLevelBox.Value && lastResult = "win") {
        AddToLog("Next level")
        ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyIcon, +260, -35)
    } else {
        AddToLog("Replay level")
        ClickReplay()
    }
    return RestartStage()
}

HandleCustomEnd() {
    global lastResult
    if (NextLevelBox.Value) {
        if (lastResult = "win") {
            AddToLog("[Game Over] Starting next level")
            ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyIcon, +260, -35)
            return RestartStage()
        }
    } else {
        AddToLog("[Game Over] Replaying stage")
        ClickReplay()
        return RestartStage()
    }
}

HandleDefaultEnd() {
    AddToLog("[Game Over] Restarting stage")
    ClickReplay()
    return RestartStage()
}

MonitorStage() {
    global Wins, loss, mode, stageStartTime

    ; -------------------------------------------------
    ; 1. Setup: Timers, anti-AFK, timeouts
    ; -------------------------------------------------
    lastClickTime := A_TickCount
    FixClick(400, 500)  ; Initial anti-AFK
    stageTimeout := A_TickCount + 3600000  ; 1 hour

    ; -------------------------------------------------
    ; 2. Main monitoring loop
    ; -------------------------------------------------
    while (true) {
        Sleep(200)

        ; --- Anti-AFK (every 10s) ---
        if (A_TickCount - lastClickTime >= 10000) {
            FixClick(400, 500)
            lastClickTime := A_TickCount
        }

        ; --- Quick progression checks ---
        if (HasCards(ModeDropdown.Text) || HasCards(EventDropdown.Text)) {
            CheckForCardSelection()
        }

        ; --- Fallbacks (early exit if needed) ---
        Reconnect()

        ; --- Wait for XP screen (break IMMEDIATELY) ---
        if (CheckForXP()) {
            break
        }
    }

    CloseMenu("Unit Manager")
    CloseMenu("Ability Manager")
    Sleep(300)

    ; Special handlers
    if (AutoAbilityBox.Value) {
        SetTimer(CheckAutoAbility, 0)
    }

    stageEndTime := A_TickCount
    stageLength := FormatStageTime(stageEndTime - stageStartTime)

    result := false

    ; Fast parallel checks
    victoryFound := (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, VictoryText) or (ok := FT(&X, &Y, 319, 176, 492, 279, 0, 0, VictoryText2)) or (ok := FT(&X, &Y, 363, 193, 475, 274, 0, 0, VictoryTextApril)))
    defeatFound := (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, DefeatText) or (ok := FT(&X, &Y, 319, 176, 492, 279, 0, 0, DefeatText2)))

    if (victoryFound) {
        result := true
    } else if (defeatFound) {
        result := false
    } else {
        AddToLog("⚠️ Warning: No clear win/loss detected - assuming defeat")
        result := false
    }

    outcome := result ? "Victory" : "Defeat"
    AddToLog(outcome " - Stage Length: " stageLength)

    if (ok := FT(&X, &Y, 260, 400, 390, 450, 0, 0, NextText)) {
        ClickUntilGone(0, 0, 260, 400, 390, 450, NextText, 0, -40)
        Sleep(1500)
    }

    ; -------------------------------------------------
    ; 6. WEBHOOK & STREAK (error-proof)
    ; -------------------------------------------------
    if (WebhookEnabled.Value) {
        try {
            SendWebhookWithTime(result, stageLength)
        } catch as err {
            AddToLog("Webhook failed: " err.Message)
        }
    } else {
        UpdateStreak(result)
    }

    HandleEndScreen(result)
    Reconnect()
}

ChallengeMovement() {
    FixClick(765, 475)
    Sleep (500)
    FixClick(300, 415)
    SendInput ("{a down}")
    sleep (7000)
    SendInput ("{a up}")
}

StartContent(mapName, actName, getMapFunc, getActFunc, mapScrollMousePos, actScrollMousePos) {
    ;AddToLog("Selecting : " mapName " - " actName)

    ; Get the map
    Map := getMapFunc.Call(mapName)
    if !Map {
        AddToLog("Error: Map '" mapName "' not found.")
        return false
    }

    ; Scroll map if needed
    if Map.scrolls > 0 {
        AddToLog(Format("Scrolling down {} times for {}", Map.scrolls, mapName))
        MouseMove(mapScrollMousePos.x, mapScrollMousePos.y)
        Scroll(Map.scrolls, 'WheelDown', 250)
    }

    Sleep(1000)
    FixClick(Map.x, Map.y)
    Sleep(1000)

    ; Get the act
    Act := getActFunc.Call(actName)
    if !Act {
        AddToLog("ERROR: Act '" actName "' not found.")
        return false
    }

    ; Scroll act if needed
    if Act.scrolls > 0 {
        AddToLog(Format("Scrolling down {} times for {}", Act.scrolls, actName))
        MouseMove(actScrollMousePos.x, actScrollMousePos.y)
        Scroll(Act.scrolls, 'WheelDown', 250)
    }

    Sleep(1000)
    FixClick(Act.x, Act.y)
    Sleep(1000)

    return true
}

PlayHere() {
    FixClick(400, 435)  ; Play Here or Find Match
    Sleep (500)
    FixClick(330, 325) ;Click Play here
    Sleep (1200)
    ClickStartStory()
    Sleep (500)
}

Zoom() {
    WinActivate(rblxID)
    Sleep 100

    MouseMove(400, 300)
    Sleep 100

    if (ZoomInOption.Value) {
        Scroll(20, "WheelUp", 50)
        ; Look down
        Click
        MouseMove(400, 400)  ; Move mouse down to angle camera down
    }
    
    ; Zoom back out smoothly
    Scroll(Integer(ZoomBox.Value), "WheelDown", 50)
    
    ; Move mouse back to center
    MouseMove(400, 300)
}

TeleportToSpawn() {
    FixClick(26, 570) ;click settings
    Sleep 300
    FixClick(400, 215)
    Sleep 300
    loop 6 {
        Sleep 150
        SendInput("{WheelDown 1}") ;scroll
    }
    Sleep 300
    if (ok := FT(&X, &Y, 215, 160, 596, 480, 0.20, 0.20, Spawn)) {
        AddToLog("Found Teleport to Spawn button")
        FixClick(X + 100, Y - 30)
    } else {
        AddToLog("Could not find Teleport button")
    }
    Sleep 300
    FixClick(583, 147)
    Sleep 300
}

RestartMatch() {
    FixClick(233, 10) ;click settings
    Sleep 300
    FixClick(338, 253) ;click restart match
    Sleep 3500
}

CloseChat() {
    if (ok := FindText(&X, &Y, 123, 50, 156, 79, 0, 0, OpenChat)) {
        AddToLog "Closing Chat"
        FixClick(138, 30) ;close chat
    }
}

BasicSetup(usedButton := false) {
    global firstStartup

    if (!WinActive(rblxID)) {
        WinActivate(rblxID)
    }

    if (ShouldUseRecording.Value) {
        if (!ShouldUseSetup.Value) {
            return
        }
    }

    if (!firstStartup) {
        if (!DoesntHaveSeamless(ModeDropdown.Text)) {
            return
        } else {

        }
    }

    ; Close various UI elements

    CloseChat()
    Sleep 250

    if (ModeDropdown.Text = "Custom" && !usedButton || ModeDropdown.Text == "Portal") {
        return
    }

    if (ZoomTech.Value) {
        Zoom()
    }

    if (ZoomTeleport.Value) {
        TeleportToSpawn()
    }

    CloseLeaderboard(false)
    Sleep 250
    
    if (!StartWalk(usedButton)) {
        if (ModeDropdown.Text = "Event") {
            if (!firstStartup) {
                return
            }
            HandleEventMovement()
        }
    }

    if (!usedButton) {
        firstStartup := false
    }
}

DoesntHaveSeamless(ModeName) {
    static modesWithoutSeamless := ["Boss Rush"]

    for mode in modesWithoutSeamless {
        if (mode = ModeName)
            return true
    }
    return true
}

DetectMap() {
    if (ModeDropdown.Text = "Raid") {
        AddToLog("Map selected: " RaidDropdown.Text)
        return RaidDropdown.Text
    } else if (ModeDropdown.Text = "Story") {
        AddToLog("Map selected: " StoryDropdown.Text)
        return StoryDropdown.Text
    } else if (ModeDropdown.Text = "Portal") {
        return PortalDropdown.Text
    } else if (ModeDropdown.Text = "Event") {
        return EventDropdown.Text
    } else {
        return "no map found"
    }
}

HandleMapMovement(MapName) {
    AddToLog("Executing Movement for: " MapName)
    switch MapName {
        case "Planet Greenie":
            MoveForPlanetGreenie()
    }
}

MoveForPlanetGreenie() {
    if !(ModeDropdown.Text = "Fool's Hunt") {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (2200)
        SendInput ("{a up}")
        SendInput ("{w up}")
    }
}
    
RestartStage() {
    
    if (TeleportFailsafe.Value) {
        TimerManager.Start("Teleport Failsafe", TeleportFailsafeTimer.Value * 1000)
    }

    ; Wait for loading
    CheckLoaded()

    BasicSetup()

    ; Wait for game to actually start
    StartedGame()

    if (ShouldUseRecording.Value) {
        PlayRecordedActions()
    } else {
        StartPlacingUnits(PlacementPatternDropdown.Text == "Custom" || PlacementPatternDropdown.Text = "Map Specific")
    }
    
    ; Monitor stage progress
    MonitorStage()
}

Reconnect(force := false) {
    if (FindText(&X, &Y, 202, 206, 601, 256, 0.10, 0.10, Disconnect) || force || TeleportFailsafe.Value && TimerManager.HasExpired("Teleport Failsafe")) {
        if (WinExist(rblxID)) {
            if (!WinActive(rblxID)) {
                WinActivate(rblxID)
            }
        }

        ; Wait until internet is available
        while !isConnectedToInternet() {
            AddToLog("❌ No internet connection. Waiting to reconnect...")
            Sleep(5000) ; wait 5 seconds before checking again
        }

        AddToLog("✅ Internet connection verified, attempting to reconnect...")
        sendDCWebhook()

        if (PrivateServerEnabled.Value) {
            psLink := PrivateServerURLBox.Value
            if (psLink != "") {
                serverCode := GetPrivateServerCode(psLink)
                deepLink := "roblox://experiences/start?placeId=8304191830&linkCode=" serverCode
                if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
                    WinClose("ahk_exe RobloxPlayerBeta.exe")
                    Sleep(3000)
                }
                AddToLog("Connecting to your private server...")
                Run(serverCode = "" ? psLink : deepLink)
                loop {
                    if WinWait("ahk_exe RobloxPlayerBeta.exe", , 15) {
                        AddToLog("New Roblox Window Found!")
                        break
                    } else {
                        AddToLog("Waiting for new Roblox Window...")
                        Sleep(1000)
                    }
                }
            }
        } else {
            Run("roblox://placeID=12886143095")
        }

        AddToLog("Reconnecting to " GameName "...")

        while (!isInLobby()) {
            if (WinExist(rblxID)) {
                WinActivate(rblxID)
                sizeDown()
            }
            Sleep(1250)
        }
        if (TeleportFailsafe.Value) {
            TimerManager.Clear("Teleport Failsafe")
        }
        Sleep(1000)
        AddToLog("Reconnected Successfully!")
        return StartSelectedMode()
    }
}

wiggle() {
    MouseMove(1, 1, 5, "R")
    Sleep(30)
    MouseMove(-1, -1, 5, "R")
}

CheckLobby() {
    loop {
        Sleep 1000
        if (CheckForLobby()) {
            break
        }
        Reconnect()
    }
    AddToLog("Returned to lobby, restarting selected mode")
    return StartSelectedMode()
}

CheckForLobby() {
    return FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)
}

CheckLoaded() {
    loop {
        Sleep(500)
        
        if (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStart) or (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStartLaptop) or (ok := FT(&X, &Y, 0, 0, 742, 287, 832, 377, 0.10, 0.10, Units) or (ok := FT(&X, &Y, 0, 0, 1080, 1080, 0, 0, UnitManager) or PixelGetColor(320, 60) = 0x00EE00)))) {
            AddToLog("Successfully Loaded In")
            if (TeleportFailsafe.Value) {
                TimerManager.Clear("Teleport Failsafe")
            }
            break
        }

        Reconnect()
    }
}

StartedGame() {
    HandleStartButton()
    AddToLog("Game started")
}

StartSelectedMode() {

    if (StartsInLobby(ModeDropdown.Text) || StartsInLobby(EventDropdown.Text)) {
        CloseLobbyPopups()
    }

    switch (ModeDropdown.Text) {
        case "Story":
            StartStoryMode()
        case "Raid":
            StartRaidMode()
        case "Custom":
            CustomMode()
        case "Portal":
            StartPortalMode()
        case "Event":
            StartEvent()
    }
}

FormatStageTime(ms) {
    seconds := Floor(ms / 1000)
    minutes := Floor(seconds / 60)
    hours := Floor(minutes / 60)
    
    minutes := Mod(minutes, 60)
    seconds := Mod(seconds, 60)
    
    return Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}

ValidateMode() {
    if (ModeDropdown.Text = "") {
        AddToLog("Please select a gamemode before starting the macro!")
        return false
    }
    if (!confirmClicked) {
        AddToLog("Please click the confirm button before starting the macro!")
        return false
    }
    return true
}

GetNavKeys() {
    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}", ",")
}

ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX:=0, offsetY:=0, textToFind2:="") {
while (ok := FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind) || textToFind2 && FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind2)) {
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)  
        } else {
            FixClick(x, y) 
        }
        Sleep(1000)
    }
}

ClickReturnToLobby() {
    ClickUntilGone(0, 0, 238, 400, 566, 445, LobbyIcon, 0, -35)
}

ClickReplay() {
    ClickUntilGone(0, 0, 238, 400, 566, 445, Retry, 0, -25)
}

SetupForInfinite() {
    ChangeCameraMode("Follow")
    Sleep (1000)
    ZoomIn()
    Sleep (1000)
    ZoomOut()
    ChangeCameraMode("Default (Classic)")
    Sleep (1000)
    SendInput ("{a down}")
    Sleep 2000
    SendInput ("{a up}")
    KeyWait "a"
}

ChangeCameraMode(mode := "") {
    AddToLog("Changing camera mode to " mode)
    SendInput("{Escape}") ; Open Roblox Menu
    Sleep (1000)
    FixClick(205, 90) ; Click Settings
    Sleep (1000)
    loop 2 {
        FixClick(336, 209) ; Change Camera Mode
        Sleep (500)
    }
    SendInput("{Escape}") ; Open Roblox Menu
}

ZoomIn() {
    MouseMove 400, 300
    Sleep 100
    FixClick(400, 300)
    Sleep 100

    ; Zoom in smoothly
    Loop 12 {
        Send "{WheelUp}"
        Sleep 50
    }

    ; Right-click and drag camera down
    Sleep 100
    MouseMove 400, 300  ; Ensure starting point
    Click "Right Down"
    Sleep 50
    MouseMove 400, 400, 20  ; Drag downward over 20ms
    Sleep 50
    Click "Right Up"
    Sleep 100
}

ZoomOut() {
    ; Zoom out smoothly
    Loop 10 {
        Send "{WheelDown}"
        Sleep 50
    }

    ; Move mouse back to center
    MouseMove 400, 300
}

DetectAngle(mode := "Story") {
    switch mode {
        case "Story":
            angle := GetPixel(0xA77EFF, 319, 40, 2, 2, 10)
            if (angle) {
                return 1
            } else {
                return 2
            }

        case "Raid":
            angle := GetPixel(0x008BFF, 154, 192, 2, 2, 10)
            if (angle) {
                return 1
            } else {
                return 2
            }
    }
    return 0
}

HandleStageEnd(waveRestart := false) {
    AddToLog("Stage ended during upgrades, proceeding to results")
    ResetPlacementTracking()
    return MonitorStage()
}

CheckForStartButton() {
    return FindText(&X, &Y, 319, 536, 396, 558, 0.10, 0.10, StartButton)
}

HandleStartButton() {
    loop {
        Sleep(1000)
        if (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStart) or (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStartLaptop))) {
            FixClick(350, 103) ; click yes
            FixClick(350, 100)
            FixClick(350, 97)
            continue  ; Keep waiting if vote screen is still there
        }
        global stageStartTime := A_TickCount
        break
    }
}

StartsInLobby(ModeName) {
    ; Array of modes that usually start in lobby
    static modes := ["Story", "Raid", "Challenge", "Infinity Castle", "Portal", "Event"]
    
    ; Special case: If PortalLobby.Value is set, don't start in lobby for "Portal"
    if (ModeName = "Portal" && !PortalLobby.Value)
        return false

    ; Check if current mode is in the array
    for mode in modes {
        if (mode = ModeName)
            return true
    }
    return false
}

isMenuOpen(name := "") {
    static menuData := Map(
        "Unit Manager", [
            [700, 142, 789, 166, 0.20, 0.20, "UnitManager"],
            [679, 595, 782, 616, 0.20, 0.20, "UnitManagerDark"]
        ],
        "Ability Manager", [
            [675, 594, 785, 616, 0.20, 0.20, "AbilityManager"]
        ],
        "End Screen", [
            [225, 217, 356, 246, 0.20, 0.20, "Results"]
        ],
        "Card Selection", [
            [436, 383, 2, 2, 3, "PixelCheck", 0x4A4747]
        ]
    )

    if !menuData.Has(name)
        return false

    for each, data in menuData[name] {
        if (data[6] = "PixelCheck") {
            if GetPixel(data[7], data[1], data[2], data[3], data[4], data[5])
                return true
        } else {
            if FindText(&X, &Y, data[1], data[2], data[3], data[4], data[5], data[6], %data[7]%)
                return true
        }
    }
    return false
}

; -------------------------------------------------
; 1. REGION CAPTURE – CLICK TWO CORNERS + COPY TO CLIPBOARD
; -------------------------------------------------
SetRegion() {
    region := [0, 0, 0, 0]

    ; ---- FIRST CLICK (top-left) ----
    AddToLog("Click TOP-LEFT of wanted search area")
    while !GetKeyState("LButton", "P") {
        Sleep(10)
    }
    while GetKeyState("LButton", "P") {
        Sleep(10)
    }
    MouseGetPos(&x1, &y1)
    AddToLog("Click BOTTOM-RIGHT of wanted search area (top-left: " x1 "," y1 ")")

    ; ---- SECOND CLICK (bottom-right) ----
    while !GetKeyState("LButton", "P") {
        Sleep(10)
    }
    while GetKeyState("LButton", "P") {
        Sleep(10)
    }
    MouseGetPos(&x2, &y2)

    regions := [x1, y1, x2, y2]

    ; ---- COPY TO CLIPBOARD (ready to paste!) ----
    clip := Format("{1}, {2}, {3}, {4}", x1, y1, x2, y2)
    A_Clipboard := clip
    AddToLog("Region: " x1 ", " y1 ", " x2 ", " y2 "")
}