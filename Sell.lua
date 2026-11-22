local ADDON, ns = ...

---------------------------------------------------------------------------
-- Auto sell at a vendor (off by default): gray items, and gear you can't use or that is worse
-- than what you wear. Greens only when soulbound (a bind-on-equip green may be for an alt or
-- the auction house), and never when you have Enchanting: those get disenchanted. Blue and
-- better is never sold.
---------------------------------------------------------------------------
local DISENCHANT = 13262
local QUEST_CLASS = 12

local function canDisenchant()
    return IsPlayerSpell and IsPlayerSpell(DISENCHANT) or false
end

-- why this bag slot can go: "gray", "unusable", "worse"; nil to keep it
local function reason(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or type(info.hyperlink) ~= "string" or info.isLocked or info.hasNoValue then return nil end
    local link = info.hyperlink
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
    if classID == QUEST_CLASS then return nil end
    local price = select(11, C_Item.GetItemInfo(link))
    if not price or price <= 0 then return nil end
    local quality = info.quality or 0
    if quality == 0 then return "gray" end
    if not ns.SLOTS[equipLoc] then return nil end -- only gear beyond gray
    if quality >= 3 then return nil end
    if quality == 2 and (canDisenchant() or not info.isBound) then return nil end
    if ns.IsEquipped(link) then return nil end
    local score, usable, loc = ns.ItemScore(link)
    if score == nil then return nil end -- not loaded: next visit
    if not usable then return "unusable" end
    local eq = ns.EquippedScore(loc)
    if not eq then return nil end -- can't compare (a different kind of off hand)
    if score < eq then return "worse" end
    return nil
end

local function sellAll()
    local list = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local why = reason(bag, slot)
            if why then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local price = select(11, C_Item.GetItemInfo(info.hyperlink)) or 0
                list[#list + 1] = { bag = bag, slot = slot, link = info.hyperlink, why = why,
                                    value = price * (info.stackCount or 1) }
            end
        end
    end
    if #list == 0 then return end
    -- one item every 0.15 s: the vendor keeps up and the buyback list stays readable
    local i, total = 0, 0
    local function nextItem()
        i = i + 1
        local it = list[i]
        if not it or not MerchantFrame or not MerchantFrame:IsShown() then
            if total > 0 then
                print(("|cff66ccffForever Gear|r: sold %d items for %s"):format(i - 1,
                    C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(total)
                    or GetCoinTextureString and GetCoinTextureString(total) or (total .. "c")))
            end
            return
        end
        C_Container.UseContainerItem(it.bag, it.slot)
        total = total + it.value
        C_Timer.After(0.15, nextItem)
    end
    nextItem()
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function()
    if ns.db and ns.db.autoSell then C_Timer.After(0.2, sellAll) end
end)
