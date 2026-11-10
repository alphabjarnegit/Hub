-- https://www.roblox.com/games/133112767606395/PlaneRNG

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Runtime = {}
Runtime.running = true
Runtime.version = "1.0.0"

-- Cleanup-Tabellen
local connections: { RBXScriptConnection } = {}
local instances: { Instance } = {}
local threads: { thread } = {}

-- Sofort global eintragen: Bricht der Code weiter unten mit einem Fehler ab,
-- findet der Loader diese Instanz trotzdem und kann sie entladen.
_G.ActiveRuntimeModule = Runtime

---------------------------------------------------------------------------
-- Helfer: alles hierüber anlegen, nie direkt
---------------------------------------------------------------------------

-- Verbindet ein Signal und merkt sich die Verbindung.
function Runtime.Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local conn = signal:Connect(fn)
	table.insert(connections, conn)
	return conn
end

-- Merkt sich eine Instanz, damit Unload() sie zerstört.
function Runtime.Track<T>(inst: T): T
	table.insert(instances, inst :: any)
	return inst
end

-- Startet eine Schleife, die endet, sobald running false wird.
-- Der Thread wird zusätzlich gespeichert und in Unload() abgebrochen,
-- falls er gerade in einem langen task.wait() hängt.
function Runtime.Loop(interval: number, fn: () -> ())
	local t = task.spawn(function()
		while Runtime.running do
			local ok, err = pcall(fn)
			if not ok then
				warn("[Runtime] Fehler in Schleife:", err)
			end
			task.wait(interval)
		end
	end)
	table.insert(threads, t)
end

---------------------------------------------------------------------------
-- Unload
---------------------------------------------------------------------------

function Runtime.Unload()
	if not Runtime.running then
		return -- schon entladen
	end
	Runtime.running = false

	-- 1. Verbindungen trennen
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	-- 2. Threads abbrechen (der aktuelle Thread darf nicht gecancelt werden)
	local current = coroutine.running()
	for _, t in threads do
		if t ~= current and coroutine.status(t) ~= "dead" then
			pcall(task.cancel, t)
		end
	end
	table.clear(threads)

	-- 3. Instanzen zerstören (rückwärts, damit Kinder vor Eltern dran sind)
	for i = #instances, 1, -1 do
		local inst = instances[i]
		pcall(inst.Destroy, inst) -- pcall: Instanz kann schon zerstört sein
	end
	table.clear(instances)

	if _G.ActiveRuntimeModule == Runtime then
		_G.ActiveRuntimeModule = nil
	end

	print("[Runtime] Version " .. Runtime.version .. " entladen")
end

---------------------------------------------------------------------------
-- Eigentliche Logik (Beispiele, nach Bedarf ersetzen)
---------------------------------------------------------------------------

-- Beispiel-Instanz
local folder = Runtime.Track(Instance.new("Folder"))
folder.Name = "HotReloadDemo"
folder.Parent = workspace

local part = Runtime.Track(Instance.new("Part"))
part.Anchored = true
part.Position = Vector3.new(0, 10, 0)
part.Parent = folder

-- Beispiel-Verbindung: Part pro Frame drehen
Runtime.Connect(RunService.Heartbeat, function(dt)
	part.CFrame *= CFrame.Angles(0, dt, 0)
end)

-- Beispiel-Verbindung: Spieler begrüßen
Runtime.Connect(Players.PlayerAdded, function(player)
	print("[Runtime] Willkommen,", player.Name)
end)

-- Beispiel-Schleife
Runtime.Loop(5, function()
	print("[Runtime] läuft noch, Version", Runtime.version)
end)

print("[Runtime] Version " .. Runtime.version .. " geladen")

return Runtime
