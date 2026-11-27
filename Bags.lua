local ADDON, ns = ...

---------------------------------------------------------------------------
-- Tooltip line: "Upgrade score 92 (+20 vs equipped)" on every gear tooltip,
-- including the "Equipped" comparison tooltip.
---------------------------------------------------------------------------
local function linkFrom(tooltip, data)
    local link
    if tooltip and tooltip.GetItem then
        local ok, _, l = pcall(tooltip.GetItem, tooltip)
        if ok and type(l) == "string" and not (issecretvalue and issecretvalue(l)) then link = l end
    end
    if not link and type(data) == "table" then
        if type(data.hyperlink) == "string" then link = data.hyperlink end
        if not link and data.guid and C_Item.GetItemLinkByGUID then
            local ok, l = pcall(C_Item.GetItemLinkByGUID, data.guid)
            if ok and type(l) == "string" then link = l end
        end
    end
    return link
end
ns.LinkFrom = linkFrom

local function addScoreLine(tooltip, data)
    if not ns.db or not ns.db.tooltip then return end
    local link = linkFrom(tooltip, data)
    if not link then return end
    local score, usable, loc = ns.ItemScore(link)
    if not score then return end
    local text
    if ns.IsEquipped(link) then
        text = ("|cff66ccffUpgrade score %s|r (equipped)"):format(score)
    elseif not usable then
        text = ("|cff66ccffUpgrade score %s|r |cffff4444(you can't use it)|r"):format(score)
    else
        local eq = ns.EquippedScore(loc)
        if eq then
            local d = score - eq
            local ahead = ns.Ahead(score, eq)
            local color = ahead > 0 and "|cff33ff33" or (ahead < 0 and "|cffff4444" or "|cffaaaaaa")
            text = ("|cff66ccffUpgrade score %s|r %s(%+.1f vs equipped)|r"):format(score, color, d)
        elseif eq == false then
            text = ("|cff66ccffUpgrade score %s|r |cffaaaaaa(not compared with your off hand)|r"):format(score)
        else
            text = ("|cff66ccffUpgrade score %s|r"):format(score)
        end
    end
    tooltip:AddLine(text)
end

---------------------------------------------------------------------------
-- Bag arrows: Bagnon draws its own upgrade arrow and asks Pawn; we answer instead.
---------------------------------------------------------------------------
local function refreshBagnon()
    local B = _G.Bagnon or _G.BagBrother
    if B and B.Frames and B.Frames.Update then pcall(B.Frames.Update, B.Frames) end
end
ns.RefreshBags = refreshBagnon

local function hookBagnon()
    local B = _G.Bagnon or _G.BagBrother
    local Item = B and B.Item
    if not Item or Item.foreverGearHooked then return Item ~= nil end
    local original = Item.IsUpgrade
    Item.IsUpgrade = function(self)
        local r = original and original(self)
        if r then return r end
        if not (ns.db and ns.db.arrows) then return false end
        local link = self.info and self.info.hyperlink
        if type(link) ~= "string" then return false end
        local ok, up = pcall(ns.IsUpgrade, link)
        if not ok then return false end
        return up -- nil = not loaded yet, Bagnon asks again shortly
    end
    Item.foreverGearHooked = true
    -- subclasses (bag/bank buttons) normally inherit it; set it on them too in case they copied methods
    for _, name in ipairs({ "ContainerItem", "BankItem", "InventoryItem" }) do
        local cls = B[name]
        if type(cls) == "table" and cls ~= Item and rawget(cls, "IsUpgrade") == original then
            cls.IsUpgrade = Item.IsUpgrade
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Default bags (no Bagnon): our own small arrow on container buttons
---------------------------------------------------------------------------
-- the green arrow on a button (bag slot, loot roll icon...)
local function arrowOn(button, show)
    if show and not button.foreverGearArrow then
        local t = button:CreateTexture(nil, "OVERLAY", nil, 7)
        local okAtlas = pcall(t.SetAtlas, t, "bags-greenarrow", true)
        if not okAtlas or not t:GetAtlas() then
            t:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
            t:SetSize(16, 16)
        end
        t:SetPoint("TOPLEFT", 1, -1)
        button.foreverGearArrow = t
    end
    if button.foreverGearArrow then button.foreverGearArrow:SetShown(show and true or false) end
end

local function upgradeOf(link)
    if not (ns.db and ns.db.arrows) or type(link) ~= "string" then return false end
    local ok, up = pcall(ns.IsUpgrade, link)
    return ok and up or false
end

local function markButton(button, bag, slot)
    if not button then return end
    arrowOn(button, upgradeOf(C_Container.GetContainerItemLink(bag, slot)))
end

-- group loot: the arrow on the roll frame's icon, before you pick need / greed / pass
local function markRollFrames()
    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
        local f = _G["GroupLootFrame" .. i]
        if f and f:IsShown() and f.rollID then
            local ok, link = pcall(GetLootRollItemLink, f.rollID)
            local icon = f.IconFrame or f
            arrowOn(icon, ok and upgradeOf(link))
        end
    end
end

local function eachShownButton(frame)
    if not (frame and frame:IsShown() and frame.EnumerateValidItems) then return end
    for _, button in frame:EnumerateValidItems() do
        local bag = button.GetBagID and button:GetBagID()
        local slot = button.GetID and button:GetID()
        if bag and slot then markButton(button, bag, slot) end
    end
end

local function updateDefaultBags()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        eachShownButton(_G["ContainerFrame" .. i])
    end
    eachShownButton(ContainerFrameCombinedBags)
end

---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local usingBagnon = false

-- one redraw a moment later, however many events asked for it
local scheduled = false
local function refreshSoon(delay)
    if scheduled then return end
    scheduled = true
    C_Timer.After(delay or 0.3, function()
        scheduled = false
        if usingBagnon then refreshBagnon() else updateDefaultBags() end
    end)
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            ForeverGearDB = ForeverGearDB or {}
            for k, v in pairs(ns.DEFAULTS) do
                if ForeverGearDB[k] == nil then ForeverGearDB[k] = v end
            end
            ForeverGearDB.margin, ForeverGearDB.marginPct = nil, nil -- 0.3.1: minGainPct, any gain by default
            ns.db = ForeverGearDB
        end
        if not usingBagnon then usingBagnon = hookBagnon() end
    elseif event == "PLAYER_LOGIN" then
        if not usingBagnon then usingBagnon = hookBagnon() end
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
                pcall(addScoreLine, tt, data)
            end)
        end
        if ns.InitOptions then ns.InitOptions() end
    elseif event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" then
        ns.ClearCache()
        refreshSoon(0.1)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        refreshSoon(0.3) -- items that were not loaded yet
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        refreshSoon(0.1) -- what counts as "equipped" changed: every arrow may flip
    elseif event == "BAG_UPDATE_DELAYED" then
        if not usingBagnon then updateDefaultBags() end
    elseif event == "START_LOOT_ROLL" then
        -- the roll frame is filled by the game's own handler: look right after it
        C_Timer.After(0, markRollFrames)
        C_Timer.After(0.5, markRollFrames) -- the item may load late
    end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
                     "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "START_LOOT_ROLL" }) do
    pcall(frame.RegisterEvent, frame, e)
end

-- default bag frames redraw when opened
if ContainerFrame_OnShow then
    pcall(hooksecurefunc, "ContainerFrame_OnShow", function() if not usingBagnon then refreshSoon(0.05) end end)
end
for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    local f = _G["ContainerFrame" .. i]
    if f then f:HookScript("OnShow", function() if not usingBagnon then refreshSoon(0.05) end end) end
end
if ContainerFrameCombinedBags then
    ContainerFrameCombinedBags:HookScript("OnShow", function() if not usingBagnon then refreshSoon(0.05) end end)
end
