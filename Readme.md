
    Steam Workshop Folder Icon Fixer
    ---------------------------------
    Run via WorkshopIconizer.bat, from inside:
        <SteamLibrary>\steamapps\workshop\content\

    What it does:
      1. Finds each numbered AppID subfolder.
      2. For each AppID, look up the matching installed game using Steam's
         library/appmanifest files locally.
      3. Picks a likely "main" exe for that game and pulls its icon.
      4. Shows the full list and asks for confirmation before touching anything.
      5. Sets each AppID folder's icon.

    Known limitations (heuristic, not guaranteed):
      - Picking the "main" exe out of a game folder is a best guess (see
        $ExcludeExePattern in .ps1 to tune it). Launchers/anti-cheat wrappers can
        sometimes cause the wrong icon to appear.
      - Games not currently installed locally or with missing launchers are skipped.
      - Icon quality is whatever Windows' default icon association returns for
        that exe; it is not always the highest-res icon embedded in the file.

This tool was created by Zanzah.com for free. <br>
https://Zanzah.com/ <br>
https://ko-fi.com/zanzah_z <br>
https://Zanzah.com/donate (PayPal) <br>
