local Config = {
    --- Whether to hide the dig cursor after selecting a square to dig.
    --- @type boolean
    hideCursorAfterDigging = true,

    --- Whether to show debugging menus.
    --- @type boolean
    debug = false
}

local modOptions = PZAPI.ModOptions:create("Excavation", "Excavation")

local tryFixCutaways = function()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        player:getChunk():invalidateRenderChunkLevel(math.floor(player:getZ()), FBORenderChunk.DIRTY_OBJECT_ADD)
    end
end

local options = {}

options.hideCursorAfterDigging = modOptions:addTickBox("Excavation_HideCursorAfterDigging",
                                                   getText("IGUI_Excavation_Options_HideCursorAfterDigging"),
                                                   true,
                                                   getText("IGUI_Excavation_Options_HideCursorAfterDigging_tooltip"))


modOptions:addButton("Excavation_TryFixCutaways",
                  getText("IGUI_Excavation_Options_TryFixCutaways"),
                  getText("IGUI_Excavation_Options_TryFixCutaways_tooltip"),
                  tryFixCutaways)

if isDebugEnabled() then
    options.debug = modOptions:addTickBox("Excavation_DEBUG",
                       "(DEBUG) Debug Excavation",
                       false,
                       "Enables debugging tools.")
end

options.apply = function()
    Config.hideCursorAfterDigging = options.hideCursorAfterDigging:getValue()
    Config.debug = isDebugEnabled() and options.debug:getValue() or false
end

return Config