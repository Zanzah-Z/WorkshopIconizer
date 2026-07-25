Tested on Windows 11.

    Steam Workshop Iconizer v0.9
    ---------------------------------
    Run via WorkshopIconizer.bat, from inside:
        <SteamLibrary>\steamapps\workshop\content\

    What it does:
      Finds each numbered AppID subfolder.
      For each AppID, looks up the matching installed game using Steam's local library/appmanifest files.
      Picks .exe and extracts the .ico
      Asks for confirmation before changing anything.
      Sets each AppID found as the folder icon.

    Known issues:
      - There is NO undo button, manually reset via Rightclick>Properties>Customize>Change-Icon (on Windows).
      - "App ID 241100 on Steam is not a traditional game, but the backend system for Steam Input Configs and controller bindings. The folder steamapps\workshop\content\241100 stores community controller layout files, configuration data, and bindings automatically generated when you play games with a controller." This folder will be skipped in future updates.
      - Picking the "main" exe out of a game folder is best guess (see $ExcludeExePattern in .ps1 to customize it). Launchers/anti-cheat wrappers can sometimes cause the wrong icon to appear.
      - Games not currently installed locally or with missing launchers are skipped.
      - Icon quality is whatever Windows' default icon association returns for that exe; it is not always the highest-res icon in the file (some .exe have multiple and/or different .ico files).


This tool was created by Zanzah.com for free. <br>
https://Zanzah.com/ <br>
https://ko-fi.com/zanzah_z <br>
https://Zanzah.com/donate (PayPal) <br>
