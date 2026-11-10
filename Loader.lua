-- Loader.lua
-- Script in ServerScriptService.
-- Voraussetzungen (Game Settings bzw. Explorer):
--   * Security -> "Allow HTTP Requests" an
--   * ServerScriptService.LoadStringEnabled = true
--
-- Neu laden: Attribut "Reload" am Script umschalten (z. B. in der Command Bar:
--   game.ServerScriptService.Loader:SetAttribute("Reload", os.clock())
-- ) oder die BindableFunction "ReloadRuntime" aufrufen.

local HttpService = game:GetService("HttpService")

local SOURCE_URL = "https://raw.githubusercontent.com/alphabjarnegit/Hub/main/Main.lua"

local reloading = false -- verhindert, dass zwei Reloads gleichzeitig laufen

-- Alte Version sicher entladen
local function unloadActive()
	local active = _G.ActiveRuntimeModule
	if active == nil then
		return
	end
	if type(active) == "table" and type(active.Unload) == "function" then
		local ok, err = pcall(active.Unload)
		if not ok then
			warn("[Loader] Fehler beim Entladen:", err)
		end
	end
	_G.ActiveRuntimeModule = nil
end

-- Neue Version holen, kompilieren und ausführen.
-- Gibt true zurück, wenn alles geklappt hat, sonst false + Fehlertext.
local function reload(): (boolean, string?)
	if reloading then
		return false, "Reload läuft bereits"
	end
	reloading = true

	-- 1. Download zuerst: Schlägt er fehl, läuft die alte Version weiter.
	--    Der Zeitstempel umgeht den Cache von GitHub Raw (sonst bis zu 5 min alt).
	local okHttp, code = pcall(HttpService.GetAsync, HttpService,
		SOURCE_URL .. "?t=" .. DateTime.now().UnixTimestampMillis, true)
	if not okHttp then
		reloading = false
		return false, "HTTP-Fehler: " .. tostring(code)
	end

	-- 2. Kompilieren: Bei Syntaxfehler bleibt ebenfalls die alte Version aktiv.
	local fn, compileErr = loadstring(code, "=Main")
	if not fn then
		reloading = false
		return false, "Syntaxfehler: " .. tostring(compileErr)
	end

	-- 3. Erst jetzt die alte Version entladen.
	unloadActive()

	-- 4. Ausführen
	local okRun, result = pcall(fn)
	if not okRun then
		-- Main trägt sich am Anfang selbst in _G ein, also Reste entfernen
		unloadActive()
		reloading = false
		return false, "Laufzeitfehler: " .. tostring(result)
	end

	if type(result) ~= "table" or type(result.Unload) ~= "function" then
		unloadActive()
		reloading = false
		return false, "Main.lua hat kein Modul mit Unload() zurückgegeben"
	end

	_G.ActiveRuntimeModule = result
	reloading = false
	return true, nil
end

local function reloadAndReport()
	local ok, err = reload()
	if ok then
		print("[Loader] Neue Version aktiv")
	else
		warn("[Loader]", err)
	end
	return ok, err
end

-- Auslöser 1: Attribut am Script
script:GetAttributeChangedSignal("Reload"):Connect(reloadAndReport)

-- Auslöser 2: BindableFunction für andere Server-Skripte / Admin-Befehle
local bindable = Instance.new("BindableFunction")
bindable.Name = "ReloadRuntime"
bindable.OnInvoke = reloadAndReport
bindable.Parent = script

-- Beim Serverstart einmal laden
reloadAndReport()

-- Beim Herunterfahren sauber entladen
game:BindToClose(unloadActive)
