local Version = require("Starlit/Version")


Events.OnGameStart.Add(function()
    -- 1.6.0 is required due to the addition of the modules module
    Version.ensureVersion(1, 6, 0)
end)
