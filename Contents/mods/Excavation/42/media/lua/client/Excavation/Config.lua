local options = PZAPI.ModOptions:create("Excavation", "Excavation")

local tryFixCutaways = function()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        player:getChunk():invalidateRenderChunkLevel(math.floor(player:getZ()), FBORenderChunk.DIRTY_OBJECT_ADD)
    end
end

local Config = {}

Config.hideCursorAfterDigging = options:addTickBox("Excavation_HideCursorAfterDigging",
                                                   getText("IGUI_Excavation_Options_HideCursorAfterDigging"),
                                                   true,
                                                   getText("IGUI_Excavation_Options_HideCursorAfterDigging_tooltip"))


options:addButton("Excavation_TryFixCutaways",
                  getText("IGUI_Excavation_Options_TryFixCutaways"),
                  getText("IGUI_Excavation_Options_TryFixCutaways_tooltip"),
                  tryFixCutaways)

return Config