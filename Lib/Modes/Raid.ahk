#Requires AutoHotkey v2.0

StartRaidMode() {

    ; Get current map and act
    currentRaidMap := RaidDropdown.Text
    currentRaidAct := RaidActDropdown.Text

    ; Execute the movement pattern
    AddToLog("Moving to position for " currentRaidMap)
    RaidMovement()

    ; Start stage
    /*while !(ok := FindText(&X, &Y, 304, 432, 399, 458, 0.10, 0.10, RaidSelectButton)) {
        RaidMovement()
    }*/

    AddToLog("Starting " currentRaidMap " - " currentRaidAct)
    StartRaid(currentRaidMap, currentRaidAct)
    ; Handle play mode selection
    PlayHere()
    RestartStage()
}

StartRaid(map, act) {
    return StartContent(map, act, GetRaidMap, GetRaidAct, { x: 195, y: 185 }, { x: 195, y: 185 })
}

RaidMovement() {
    Teleport("Raid")
    Sleep (1000)
    spawnAngle := DetectAngle("Raid")
    WalkToRaidRoom(spawnAngle)
    Sleep (1000)
}

WalkToRaidRoom(angle) {
    switch angle {
        case 1:
            Walk("a", 800)
            Walk("w", 2000)
        case 2:
            Walk("s", 800)
            Walk("a", 2000)
    }
}

GetRaidMap(map) {
    switch map {
        case "Marines Fort": return { x: 185, y: 185, scrolls: 0 }
    }
}

GetRaidAct(act) {
    baseY := 185
    spacing := 30
    x := 270

    ; Extract the act number from the string, e.g., "Act 3" → 3
    if RegExMatch(act, "Act\s*(\d+)", &match) {
        actNumber := match[1]
        y := baseY + spacing * (actNumber - 1)
        return { x: x, y: y, scrolls: 0 }
    }

    ; Default return if the input doesn't match expected format
    return { x: x, y: baseY, scrolls: 0 }
}