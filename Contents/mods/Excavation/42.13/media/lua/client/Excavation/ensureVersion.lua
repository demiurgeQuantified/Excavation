local Version = require("Starlit/Version")


Events.OnGameStart.Add(function()
    -- 2.1.2 is required due to API changes mandated by 42.20
	-- this actually breaks compatibility with 42.13-14 as these versions only support up to v1.6.0, but i don't care
    Version.ensureVersion(2, 1, 2)
end)
