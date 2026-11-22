local ADDON, ns = ...

local ICON = "Interface\\Icons\\INV_Chest_Chain_05"
local win, mini

local function build()
    local db = ns.db
    win = ns.UI.Window("ForeverGearOptions", "Forever Gear", 320)
    win:AddCheck("Green arrow on better items in bags", function() return db.arrows end,
        function(v) db.arrows = v; ns.RefreshBags() end)
    win:AddCheck("Upgrade score in item tooltips", function() return db.tooltip end,
        function(v) db.tooltip = v end)
    win:AddSlider("Count as better when ahead by", 0, 10, 1, function() return db.margin end,
        function(v) db.margin = v; ns.RefreshBags() end, function(v) return v == 1 and "1 point" or ("%d points"):format(v) end)
    win:AddCheck("Sell at vendors: gray items, and gear you can't use or that is worse than yours (soulbound greens only, none with Enchanting; blue and better never)",
        function() return db.autoSell end, function(v) db.autoSell = v or nil end)
    win:AddCheck("Minimap button", function() return not db.minimapHide end,
        function(v) db.minimapHide = not v; mini:UpdateShown() end)
    win:Finish()
end

function ns.ToggleOptions()
    if not win then build() end
    win:Toggle()
end

function ns.InitOptions()
    mini = ns.UI.MinimapButton({
        name = "ForeverGearMinimapButton",
        icon = ICON,
        db = ns.db,
        angle = 195,
        title = "Forever Gear",
        lines = function() return { "Left-click: settings", "Right-click: arrows in bags on/off", "Drag: move around the minimap" } end,
        onLeft = ns.ToggleOptions,
        onRight = function()
            ns.db.arrows = not ns.db.arrows
            ns.RefreshBags()
            print("|cff66ccffForever Gear|r: arrows " .. (ns.db.arrows and "on" or "off"))
        end,
    })
end

SLASH_FOREVERGEAR1 = "/fgear"
SlashCmdList.FOREVERGEAR = function() ns.ToggleOptions() end

function ForeverGear_OnAddonCompartmentClick()
    ns.ToggleOptions()
end
