local ADDON, ns = ...

-- Upgrade score: stats weighted for your class (rough leveling values),
-- weapon damage per second, and "Equip:" bonuses read from the tooltip.

ns.DEFAULTS = { arrows = true, tooltip = true, margin = 1 }

local W = {
    HUNTER  = { AGI = 1, RAP = 0.45, AP = 0.45, STA = 0.3, INT = 0.25, STR = 0.05, SPI = 0.05, ARMOR = 0.01,
                CRIT = 15, HIT = 12, MP5 = 1, RANGED_DPS = 12, MELEE_DPS = 1.5 },
    WARRIOR = { STR = 1, AGI = 0.7, AP = 0.5, STA = 0.45, ARMOR = 0.02, CRIT = 14, HIT = 12, MELEE_DPS = 9, RANGED_DPS = 0.5 },
    ROGUE   = { AGI = 1, STR = 0.5, AP = 0.5, STA = 0.35, ARMOR = 0.01, CRIT = 14, HIT = 12, MELEE_DPS = 9, RANGED_DPS = 0.5 },
    PALADIN = { STR = 1, INT = 0.5, STA = 0.45, AGI = 0.4, SPI = 0.2, AP = 0.5, SP = 0.6, HEAL = 0.4, ARMOR = 0.02,
                CRIT = 12, HIT = 10, MP5 = 1, MELEE_DPS = 8 },
    SHAMAN  = { INT = 1, STR = 0.5, AGI = 0.4, STA = 0.45, SPI = 0.3, AP = 0.4, SP = 0.8, HEAL = 0.5, ARMOR = 0.01,
                CRIT = 12, HIT = 10, MP5 = 1.5, MELEE_DPS = 6 },
    DRUID   = { AGI = 0.8, INT = 0.8, STR = 0.6, STA = 0.45, SPI = 0.3, AP = 0.4, SP = 0.7, HEAL = 0.5, ARMOR = 0.01,
                CRIT = 12, HIT = 10, MP5 = 1.5, MELEE_DPS = 3 },
    MAGE    = { INT = 1, SPI = 0.5, STA = 0.45, SP = 1, CRIT = 12, HIT = 12, MP5 = 1.5, ARMOR = 0.005, RANGED_DPS = 4, MELEE_DPS = 0.3 },
    WARLOCK = { INT = 0.9, STA = 0.7, SPI = 0.4, SP = 1, CRIT = 10, HIT = 12, MP5 = 1, ARMOR = 0.005, RANGED_DPS = 4, MELEE_DPS = 0.3 },
    PRIEST  = { INT = 1, SPI = 0.8, STA = 0.45, SP = 0.9, HEAL = 0.6, CRIT = 10, HIT = 10, MP5 = 1.5, ARMOR = 0.005, RANGED_DPS = 4, MELEE_DPS = 0.3 },
}

local STAT_KEYS = {
    ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT_R", ITEM_MOD_HIT_RATING_SHORT = "HIT_R",
    RESISTANCE0_NAME = "ARMOR",
}

-- "Equip:" lines that are not in the stat table (enUS client text)
local EQUIP = {
    { "^equip: %+(%d+) ranged attack power", "RAP" },
    { "^equip: %+(%d+) attack power%.?$", "AP" },
    { "^equip: improves your chance to get a critical strike by (%d+)%%", "CRIT" },
    { "^equip: improves your chance to get a critical strike with missile weapons by (%d+)%%", "CRIT" },
    { "^equip: improves your chance to hit by (%d+)%%", "HIT" },
    { "^equip: increases damage and healing done by magical spells and effects by up to (%d+)", "SP" },
    { "^equip: increases damage done by %a+ spells and effects by up to (%d+)", "SP" },
    { "^equip: increases healing done by spells and effects by up to (%d+)", "HEAL" },
    { "^equip: restores (%d+) mana per 5 sec", "MP5" },
}

local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local SKIP = { INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true, INVTYPE_BODY = true, INVTYPE_TABARD = true, [""] = true }

-- equipLoc -> inventory slots to compare against
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
ns.SLOTS = SLOTS

local weights
local function getWeights()
    if not weights then
        local _, class = UnitClass("player")
        weights = W[class] or W.WARRIOR
    end
    return weights
end

local function isRed(c)
    return c and c.r and c.r > 0.95 and c.g < 0.2 and c.b < 0.2
end

local function tooltipLines(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if ok and type(data) == "table" then return data.lines end
end

-- cache: link -> { score, usable, equipLoc } ; cleared on level up
local cache = {}
function ns.ClearCache() wipe(cache) end

-- returns score, usable, equipLoc  (nil if the item is not loaded yet)
function ns.ItemScore(link)
    if not link then return nil end
    local c = cache[link]
    if c then return c.score, c.usable, c.loc end

    local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(link)
    if not equipLoc then
        pcall(C_Item.RequestLoadItemDataByID, C_Item.GetItemInfoInstant(link))
        return nil
    end
    if SKIP[equipLoc] or not SLOTS[equipLoc] then
        cache[link] = { score = nil, usable = false, loc = equipLoc }
        return nil, false, equipLoc
    end

    local w = getWeights()
    local score = 0
    local stats = C_Item.GetItemStats and C_Item.GetItemStats(link) or {}
    for key, value in pairs(stats) do
        if key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
            score = score + value * ((RANGED[equipLoc] and w.RANGED_DPS) or w.MELEE_DPS or 0)
        else
            local k = STAT_KEYS[key]
            if k and w[k] then score = score + value * w[k] end
        end
    end

    local usable = true
    local lines = tooltipLines(link)
    if lines then
        for _, line in ipairs(lines) do
            local text = line.leftText
            if text and text ~= "" then
                if isRed(line.leftColor) or isRed(line.rightColor) then
                    -- red text in an item tooltip: wrong level, class or weapon/armor skill
                    usable = false
                end
                local lower = text:lower()
                if lower:find("^equip:") then
                    for _, p in ipairs(EQUIP) do
                        local n = lower:match(p[1])
                        if n and w[p[2]] then
                            score = score + tonumber(n) * w[p[2]]
                            break
                        end
                    end
                end
            end
        end
    else
        return nil -- tooltip not ready
    end

    score = math.floor(score * 10 + 0.5) / 10
    cache[link] = { score = score, usable = usable, loc = equipLoc }
    return score, usable, equipLoc
end

-- what sits in the off hand: a shield or a held item is a choice (tank, caster), not
-- something a weapon upgrades
local OFF_KIND = {
    INVTYPE_WEAPON = "weapon", INVTYPE_WEAPONOFFHAND = "weapon",
    INVTYPE_SHIELD = "shield", INVTYPE_HOLDABLE = "holdable",
}
local function offHandKind()
    local id = GetInventoryItemID("player", 17)
    if not id then return nil end
    local _, _, _, loc = C_Item.GetItemInfoInstant(id)
    return OFF_KIND[loc]
end

-- score of what you wear in the slots this item would replace (lowest of rings/trinkets/1h pair);
-- false when it would only replace a different kind of off hand (a dagger for your shield)
function ns.EquippedScore(equipLoc)
    local slots = SLOTS[equipLoc]
    if not slots then return nil end
    local off = offHandKind()
    if equipLoc == "INVTYPE_2HWEAPON" and off == "shield" then return false end
    if equipLoc == "INVTYPE_2HWEAPON" then
        local sum, any = 0, false
        for _, s in ipairs({ 16, 17 }) do
            local l = GetInventoryItemLink("player", s)
            if l then
                local sc = ns.ItemScore(l)
                if sc == nil then return nil end
                sum, any = sum + sc, true
            end
        end
        return sum, any
    end
    local best
    for _, s in ipairs(slots) do
        local l = GetInventoryItemLink("player", s)
        local sc = 0
        if l then
            sc = ns.ItemScore(l)
            if sc == nil then return nil end
        end
        -- one-handers: only compare with the off hand if you can dual wield;
        -- off hand: only weapon vs weapon, shield vs shield, held item vs held item
        local skip = s == 17 and ((equipLoc == "INVTYPE_WEAPON" and not (IsPlayerSpell and IsPlayerSpell(674)))
            or (off and off ~= OFF_KIND[equipLoc]))
        if not skip then
            if not best or sc < best then best = sc end
        end
    end
    if best == nil then return false end
    return best, true
end

function ns.IsEquipped(link)
    for s = 1, 19 do
        if GetInventoryItemLink("player", s) == link then return true end
    end
    return false
end

-- true / false / nil (not loaded yet)
function ns.IsUpgrade(link)
    local score, usable, loc = ns.ItemScore(link)
    if score == nil then
        if usable == false then return false end
        return nil
    end
    if not usable or score <= 0 or ns.IsEquipped(link) then return false end
    local eq = ns.EquippedScore(loc)
    if eq == false then return false end
    if eq == nil then return nil end
    return score > eq + (ns.db and ns.db.margin or 1)
end
