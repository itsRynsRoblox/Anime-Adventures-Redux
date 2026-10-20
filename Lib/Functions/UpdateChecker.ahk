#Requires AutoHotkey v2.0

CheckForUpdates() {
    global repoOwner, repoName, version

    if (!UpdateChecker.Value) {
        return
    }

    ; --- Get latest release info from GitHub ---
    url := "https://api.github.com/repos/" repoOwner "/" repoName "/releases/latest"
    http := ComObject("MSXML2.XMLHTTP")
    http.Open("GET", url, false)
    http.Send()

    if (http.Status != 200) {
        AddToLog("❌ Failed to check for updates. HTTP " http.Status)
        AddToLog("Current Version: " version)
        return
    }

    response := http.responseText
    file := JSON.parse(response)
    latestVersion := file["tag_name"]
    assets := file["assets"]

    ; --- Read release title and description (changelog) ---
    releaseTitle := file.Has("name") ? file["name"] : latestVersion
    if file.Has("body") && file["body"] != ""
        releaseNotes := file["body"]
    else
        releaseNotes := "(No changelog or description provided for this release.)"

    ; Clean up for readability
    releaseNotes := StrReplace(releaseNotes, "`r", "")
    releaseNotes := StrReplace(releaseNotes, "`n`n", "`n")

    ; --- Compare versions ---
    comparison := VerCompare(version, latestVersion)

    if (comparison < 0) {
        MainUI.Opt("-AlwaysOnTop")

        ; Truncate long changelog for readability
        if StrLen(releaseNotes) > 1200
            releaseNotes := SubStr(releaseNotes, 1, 1200) "`n... (truncated)"

        ; --- Prompt user for update ---
        msg :=
            (
                "Current: " version " → Latest: v" latestVersion
                "`n`n" releaseNotes
                "`n`nDo you want to download and install it now?"
                "`n`nNote: Your Settings folder will be backed up and preserved."
            )

        MsgBoxResult := MsgBox(msg, "New Update Available", "YesNo")

        if (MsgBoxResult = "Yes") {
            AddToLog("⬇️ Accepted update, starting download...")

            if (assets.Length = 0) {
                MainUI.Opt("+AlwaysOnTop")
                AddToLog("⚠️ No release files found for version " latestVersion)
                return
            }

            ; --- Download the first asset ---
            downloadUrl := assets[1]["browser_download_url"]
            fileName := A_Temp "\" assets[1]["name"]
            Download(downloadUrl, fileName)

            ; --- Create a unique script-local temp extraction folder ---
            extractDir := A_ScriptDir "\update_extract_" A_TickCount
            DirCreate(extractDir)

            ; --- Extract update ZIP to this folder ---
            psCmd := Format('powershell -NoProfile -Command "Expand-Archive -Force ' '{}' ' ' '{}' '"', fileName,
                extractDir)
            RunWait(psCmd, , "Hide")

            ; --- Backup user Settings ---
            settingsDir := A_ScriptDir "\Settings"
            if DirExist(settingsDir) {
                backupDir := A_ScriptDir "\Settings_Backup_" version
                DirCreate(backupDir)
                DirCopy(settingsDir, backupDir, true)
                AddToLog("💾 Backed up settings...")
            }

            ; --- Delete old files but preserve key folders ---
            loop files, A_ScriptDir "\*.*", "R" {
                file := A_LoopFileFullPath

                if InStr(file, "\Settings\")
                    continue
                if InStr(file, "\Settings_Backup_")
                    continue
                if (file = A_ScriptFullPath)
                    continue
                if InStr(file, extractDir)
                    continue

                FileDelete(file)
            }

            ; --- Remove empty folders safely ---
            loop files, A_ScriptDir "\*", "DR" {
                dir := A_LoopFileFullPath

                if InStr(dir, "\Settings") || InStr(dir, "\Settings_Backup_") || InStr(dir, extractDir)
                    continue

                try DirDelete(dir, false)  ; delete only if empty, skip errors
                catch
                    continue
            }

            ; --- Copy new update contents ---
            DirCopy(extractDir, A_ScriptDir, true)
            AddToLog("✅ Update files copied successfully")

            ; --- Clean up temporary extraction folder ---
            try {
                DirDelete(extractDir, true)  ; true = recursive delete
            }


            Sleep(2000)
            Run(A_ScriptFullPath)
            ExitApp
        } else {
            MainUI.Opt("+AlwaysOnTop")
        }

    } else if (comparison > 0) {
        AddToLog("🚨 Your version is newer than the latest published (" latestVersion ")")
    } else {
        AddToLog("✅ You are already using the latest version (" version ")")
    }
}

; W.I.P (DON'T USE THIS YET)
OpenVersionDownloader() {
    global repoOwner, repoName, version, MainUI

    ; -------------------------------------------------
    ; 1. Fetch ALL releases from GitHub
    ; -------------------------------------------------
    url := "https://api.github.com/repos/" repoOwner "/" repoName "/releases"
    try {
        http := ComObject("MSXML2.XMLHTTP")
        http.Open("GET", url, false)
        http.Send()
        if (http.Status != 200)
            throw Error("HTTP " http.Status)

        releases := JSON.parse(http.responseText)
        if (!releases.Length)
            throw Error("No releases found")
    } catch as e {
        AddToLog("Failed to fetch releases: " e.Message)
        return
    }

    ; -------------------------------------------------
    ; 2. Build version dropdown (latest first)
    ; -------------------------------------------------
    versions := []
    versionMap := Map()  ; tag → release object

    for release in releases {
        tag := release["tag_name"]
        versions.Push(tag)
        versionMap[tag] := release
    }

    ; === MANUAL SORT: LATEST → OLDEST (works in ALL AHK v2.0 versions) ===
    loop (versions.Length - 1) {
        swapped := false
        loop (versions.Length - A_Index) {
            i := A_Index
            if (VerCompare(versions[i], versions[i + 1]) < 0) {
                ; Swap
                temp := versions[i]
                versions[i] := versions[i + 1]
                versions[i + 1] := temp
                swapped := true
            }
        }
        if (!swapped)
            break
    }

    ; -------------------------------------------------
    ; 3. Create Update GUI
    ; -------------------------------------------------
    MainUI.Opt("-AlwaysOnTop")
    UpdateGUI := Gui(, "Update Manager")
    UpdateGUI.AddText("w300", "Select a version to install:")
    ddl := UpdateGUI.AddDropDownList("w300 vSelectedVersion", versions)

    currentVersion := RegExReplace(version, "^v", "")
    found := false
    for i, item in versions {
        if (RegExReplace(item, "^v", "") = currentVersion) {
            ddl.Choose(i)
            found := true
            break
        }
    }
    if (!found)
        ddl.Choose(1)  ; fallback to latest

    UpdateGUI.AddText("w300 vStatus", "Ready.")

    btn := UpdateGUI.AddButton("w300", "Download && Install")
    btn.OnEvent("Click", (*) => InstallSelectedVersion())

    UpdateGUI.Show("AutoSize Center")

    ; -------------------------------------------------
    ; 4. Install Logic (shared for latest & older)
    ; -------------------------------------------------
    InstallSelectedVersion() {
        selected := UpdateGUI["SelectedVersion"].Text
        if (!selected) {
            UpdateGUI["Status"].Text := "Please select a version."
            return
        }

        release := versionMap[selected]
        assets := release["assets"]
        if (!assets.Length) {
            UpdateGUI["Status"].Text := "No downloadable files."
            return
        }

        ; Use first .zip or .exe
        asset := assets[1]
        downloadUrl := asset["browser_download_url"]
        fileName := A_Temp "\" asset["name"]

        UpdateGUI["Status"].Text := "Downloading " selected "..."

        try {
            Download(downloadUrl, fileName)
        } catch {
            UpdateGUI["Status"].Text := "Download failed."
            return
        }

        UpdateGUI["Status"].Text := "Installing " selected "..."
        InstallUpdate(fileName, selected, release)
    }

    ; -------------------------------------------------
    ; 5. Core Installer (used by both latest & older)
    ; -------------------------------------------------
    InstallUpdate(zipPath, newVersion, release) {
        ; --- Changelog ---
        notes := release.Has("body") ? release["body"] : "(No notes)"
        notes := StrReplace(notes, "`r", "")
        notes := StrReplace(notes, "`n`n", "`n")
        if StrLen(notes) > 1000
            notes := SubStr(notes, 1, 1000) " ... (truncated)"

        ; --- Confirm ---
        msg := Format(
            "Install v{}?`n`n{} `n`nSettings will be backed up.",
            newVersion, notes
        )
        if MsgBox(msg, "Confirm Install", "YesNo") != "Yes"
            return

        AddToLog("Installing v" newVersion "...")

        ; --- Extract ---
        extractDir := A_ScriptDir "\update_extract_" A_TickCount
        DirCreate(extractDir)

        psCmd := Format('powershell -NoProfile -Command "Expand-Archive -Force ' '{}' ' ' '{}' '"', zipPath, extractDir
        )
        try RunWait(psCmd, , "Hide")
        catch {
            UpdateGUI["Status"].Text := "Extraction failed."
            return
        }

        ; --- Backup Settings ---
        settingsDir := A_ScriptDir "\Settings"
        if DirExist(settingsDir) {
            backupDir := A_ScriptDir "\Settings_Backup_" version
            DirCreate(backupDir)
            DirCopy(settingsDir, backupDir, true)
            AddToLog("Backed up settings to " backupDir)
        }

        ; --- Replace files ---
        loop files, A_ScriptDir "\*.*", "R" {
            f := A_LoopFileFullPath
            if InStr(f, "\Settings\") || InStr(f, "\Settings_Backup_") || InStr(f, extractDir) || (f = A_ScriptFullPath
            )
                continue
            try FileDelete(f)
        }

        ; --- Copy new files ---
        DirCopy(extractDir, A_ScriptDir, true)
        AddToLog("Update installed: v" newVersion)

        ; --- Cleanup ---
        try DirDelete(extractDir, true)
        FileDelete(zipPath)

        ; --- Restart ---
        UpdateGUI["Status"].Text := "Restarting..."
        Sleep(1000)
        Run(A_ScriptFullPath)
        ExitApp
    }
}