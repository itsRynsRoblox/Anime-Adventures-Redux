#Requires AutoHotkey v2.0

global contractPageCounter := 0
global contractSwitchPattern := 0

HandleContractJoin() {
    loop { ; Optimised retry loop (was: return HandleContractJoin())
        selectedPage := ContractPageDropdown.Text
        joinType := ContractJoinDropdown.Text

        ; Handle 4-5 Page pattern selection
        if (selectedPage = "Page 4-5") {
            selectedPage := GetContractPage()
            AddToLog("Pattern selected: " selectedPage)
        }

        pageNum := selectedPage = "Page 4-5" ? GetContractPage() : selectedPage
        pageNum := Integer(RegExReplace(RegExReplace(pageNum, "Page\s*", ""), "-.*", ""))

        ; Define click coordinates for each page
        clickCoords := Map(
            1, { openHere: { x: 170, y: 420 }, matchmaking: { x: 240, y: 420 } },  ; Example coords for page 1
            2, { openHere: { x: 330, y: 420 }, matchmaking: { x: 400, y: 420 } },  ; Example coords for page 2
            3, { openHere: { x: 490, y: 420 }, matchmaking: { x: 560, y: 420 } }, ; Example coords for page 3
            4, { openHere: { x: 237, y: 420 }, matchmaking: { x: 305, y: 420 } },  ; Example coords for page 4
            5, { openHere: { x: 397, y: 420 }, matchmaking: { x: 465, y: 420 } },  ; Example coords for page 5
            6, { openHere: { x: 557, y: 420 }, matchmaking: { x: 625, y: 420 } }  ; Example coords for page 6
        )

        ; First scroll if needed for pages 4-6
        if (pageNum >= 4) {
            FixClick(445, 300)
            Sleep(200)
            loop 5 {
                SendInput("{WheelDown}")
                Sleep(150)
            }
            Sleep(300)
        }

        if (TeamSwap.Value) {
            CheckBuffs()
        }
        Sleep 1500

        ; Get coordinates for the selected page
        pageCoords := clickCoords[pageNum]

        ; Handle different join types
        if (joinType = "Creating") {
            AddToLog("Creating contract portal on page " pageNum)
            FixClick(pageCoords.openHere.x, pageCoords.openHere.y)
            Sleep(300)
            FixClick(255, 355)
            Sleep(20000)
            AddToLog("Waiting 20 seconds for others to join")
            FixClick(400, 460)
        } else if (joinType = "Joining") {
            AddToLog("Attempting to join by holding E")
            SendInput("{e down}")
            Sleep(5000)
            SendInput("{e up}")
        } else if (joinType = "Solo") {
            AddToLog("Attempting to start solo")
            FixClick(pageCoords.openHere.x, pageCoords.openHere.y)
            Sleep(300)
            FixClick(255, 355)
            Sleep 300
            FixClick(400, 468) ; Start Contract
        } else if (joinType = "Matchmaking") {
            AddToLog("Joining matchmaking for contract on page " pageNum)
            FixClick(pageCoords.matchmaking.x, pageCoords.matchmaking.y)  ; Click matchmaking button
            Sleep(300)

            ; Try captcha
            if (!CaptchaDetect(252, 292, 300, 50, 400, 335)) {
                AddToLog("Captcha not detected, retrying...")
                FixClick(585, 190)  ; Click close
                return
            }
            FixClick(300, 385)  ; Enter captcha

            startTime := A_TickCount
            while (A_TickCount - startTime < 20000) {  ; Check for 20 seconds
                if !(ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                    AddToLog("Area text gone - matchmaking successful")
                    return true
                }
                Sleep(200)  ; Check every 200ms
            }

            AddToLog("Matchmaking failed - still on area screen after 20s, retrying...")
            FixClick(445, 220)
            Sleep(1000)
            loop 5 {
                SendInput("{WheelUp}")
                Sleep(150)
            }
            Sleep(1000)
            continue ; retry (was: return HandleContractJoin())
        }

        AddToLog("Joining Contract Mode")
        return true
    }
}

GetContractPage() {
    global contractPageCounter, contractSwitchPattern

    if (contractSwitchPattern = 0) {  ; During page 4 phase
        contractPageCounter++
        if (contractPageCounter >= 6) {  ; After 6 times on page 4
            contractPageCounter := 0
            contractSwitchPattern := 1  ; Switch to page 5
            return "Page 5"
        }
        return "Page 4"
    } else {  ; During page 5 phase
        contractPageCounter := 0
        contractSwitchPattern := 0  ; Switch back to page 4 pattern
        return "Page 4"
    }
}

CheckBuffs() {
    contractPage := ContractPageDropdown.Text
    ; Handle 4-5 Page pattern selection
    if (contractPage = "Page 4-5") {
        contractPage := GetContractPage()
    }
    pages := [{ name: "Page 1", coords: [131, 232, 286, 477] }, { name: "Page 2", coords: [292, 232, 443, 477] }, { name: "Page 3",
        coords: [450, 231, 605, 477] }, { name: "Page 4", coords: [196, 229, 351, 477] }, { name: "Page 5", coords: [
            358, 229, 510, 477] }, { name: "Page 6", coords: [517, 232, 668, 476] },
    ]

    for index, page in pages {
        if (contractPage = page.name) {
            if (ok := FT(&X, &Y, page.coords[1], page.coords[2], page.coords[3], page.coords[4], 0, 0, PhysicalBuff)) {
                AddToLog("Found Physical Buff")
                Sleep 1000
                SwapTeam(false)
            } else {
                if (ok := FT(&X, &Y, page.coords[1], page.coords[2], page.coords[3], page.coords[4], 0, 0, MagicBuff)) {
                    AddToLog("Found Magic Buff")
                    Sleep 1000
                    SwapTeam(true)
                }
            }
        }
    }
}

SwapTeam(magic := false) {
    global physicalTeam, magicTeam
    teamNum := magic ? magicTeam.Text : physicalTeam.Text
    teamNum := Integer(RegExReplace(RegExReplace(teamNum, "", ""), "", ""))

    SendInput("K") ; Open Units
    Sleep 1000
    FixClick(398, 223) ; Click Teams
    Sleep 1000

    teams := [{ name: "1", coords: [556, 230] }, { name: "2", coords: [556, 320] }, { name: "3", coords: [556, 410] }, { name: "4",
        coords: [556, 256] }, { name: "5", coords: [566, 340] }, { name: "6", coords: [566, 427] },
    ]

    if (teamNum >= 3) {
        FixClick(390, 245)
        Sleep(200)
        loop 5 {
            SendInput("{WheelDown}")
            Sleep(150)
        }
        Sleep(300)
    }
    for index, team in teams {
        if (magic) {
            if (magicTeam.Text = team.name) {
                AddToLog("Equipped Magic Team")
                FixClick(team.coords[1], team.coords[2])
                Sleep 300
            }
        } else {
            if (physicalTeam.Text = team.name) {
                AddToLog("Equipped Physical Team")
                FixClick(team.coords[1], team.coords[2])
                Sleep 300
            }
        }
    }
    FixClick(33, 400) ; Reopen Contracts
    Sleep 1000
}