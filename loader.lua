-- Loader.lua (Client-side / Executor)
local ENV = getgenv()
local REPO_URL = "https://raw.githubusercontent.com/alphabjarnegit/Hub/main/"

-- 1. Alte Loader-Instanz schließen, falls vorhanden
if ENV.ActiveLoaderWindow then
    pcall(function() ENV.ActiveLoaderWindow:Destroy() end)
    ENV.ActiveLoaderWindow = nil
end

print("[Loader] Version 1.0 geladen")

-- 2. UILibrary dynamisch laden
local uiLibCode = game:HttpGet(REPO_URL .. "UILibrary.lua?t=" .. DateTime.now().UnixTimestampMillis)
local UILibrary = loadstring(uiLibCode)()

-- 3. Loader-Fenster erstellen
local window = UILibrary.CreateWindow("Script Dashboard", UDim2.fromOffset(480, 320))
ENV.ActiveLoaderWindow = window

-- Tab erstellen
local mainTab = window:AddTab("Dashboard")

-- Grid-Layout für die 4 Buttons
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -8, 0.5, -8)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.Parent = mainTab

-- Hilfsfunktion zum sicheren Nachladen von Skripten
local function executeRemote(url)
    task.spawn(function()
        local success, code = pcall(function() 
            return game:HttpGet(url .. "?t=" .. DateTime.now().UnixTimestampMillis) 
        end)
        if success then
            local fn, err = loadstring(code)
            if fn then 
                pcall(fn) 
            else 
                warn("[Loader] Syntaxfehler:", err) 
            end
        else
            warn("[Loader] HTTP-Fehler:", code)
        end
    end)
end

-- Feld 1: Cobalt
window:AddButton(mainTab, "Load Cobalt UI", function()
    executeRemote("https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau")
end)

-- Feld 2: Dex Explorer
window:AddButton(mainTab, "Load Dex Explorer", function()
    executeRemote("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua")
end)

-- Feld 3: Infinite Yield
window:AddButton(mainTab, "Load Infinite Yield", function()
    executeRemote("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")
end)

-- Feld 4: Game Detected (prüft /games/<PlaceId>.lua im Repo)
local placeId = game.PlaceId
local gameScriptUrl = REPO_URL .. "games/" .. tostring(placeId) .. ".lua"

local scriptExists = pcall(function() 
    local res = game:HttpGet(gameScriptUrl)
    return res and #res > 0 and not res:find("404")
end)

local btnLabel = scriptExists and ("Game Detected (" .. placeId .. ")") or ("No Script for ID " .. placeId)

local gameBtn = window:AddButton(mainTab, btnLabel, function()
    if scriptExists then
        executeRemote(gameScriptUrl)
    end
end)

if not scriptExists and gameBtn then
    gameBtn.AutoButtonColor = false
    gameBtn.BackgroundTransparency = 0.5
end