-- Books on map (Forever): automatic detection (bags and library turn-ins)
local _, ns = ...
local BOOKS = ns.BOOKS

local function norm(s)
  -- French client: curly apostrophe and (narrow) no-break spaces before : ? !
  return ((s or ""):gsub("’", "'"):gsub("\194\160", ""):gsub("\226\128\175", ""):lower():gsub("[%s%p]", ""))
end
-- English and French names, computed before the names are localized
for _, b in ipairs(BOOKS) do
  b.norms = { norm(b.name), b.frName and norm(b.frName) }
end

local numSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local itemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink

-- calls fn(link) for every item in the backpack and bags
function ns.ForEachBagItem(fn)
  for bag = 0, 4 do
    for slot = 1, (numSlots(bag) or 0) do
      local link = itemLink(bag, slot)
      if link then fn(link) end
    end
  end
end

local NEAR = 40 -- yards: an unknown item looted this close to a book is that book

local function worldPos(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
  local cont, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
  if pos then return cont, pos.x, pos.y end
end

-- closest uncollected book within NEAR yards of the player
local function nearbyBook()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local p = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if not p then return end
  local pc, px, py = worldPos(mapID, p.x, p.y)
  if not pc then return end
  local best, bestD
  for _, b in ipairs(BOOKS) do
    if not ns.IsDone(b) then
      for _, loc in ipairs(b.locs) do
        local c, x, y = worldPos(loc[1], loc[2] / 100, loc[3] / 100)
        if c == pc then
          local d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
          if d <= NEAR and (not bestD or d < bestD) then best, bestD = b, d end
        end
      end
    end
  end
  return best
end

-- itemID match first (any language), exact name match as fallback
local function checkItem(link)
  local id = tonumber(link:match("item:(%d+)"))
  local n = norm(link:match("%[(.-)%]"))
  for _, b in ipairs(BOOKS) do
    if not ns.IsDone(b) then
      local hit = id and (b.item == id or ns.db.itemIDs[b.key] == id)
      if not hit and n ~= "" then
        for _, bn in ipairs(b.norms) do
          if n == bn then hit = true break end
        end
      end
      if hit then ns.SetDone(b, true) end
    end
  end
end

-- items present in the bags at the previous scan (to spot new loot)
local known

local function scanBags()
  local now = {}
  ns.ForEachBagItem(function(link)
    local id = tonumber(link:match("item:(%d+)"))
    if id then now[id] = true end
    checkItem(link)
  end)
  -- fallback: a new item looted right next to an uncollected book
  if known then
    for id in pairs(now) do
      if not known[id] then
        local b = nearbyBook()
        if b then
          ns.db.itemIDs[b.key] = id -- learned: detected by itemID from now on
          ns.SetDone(b, true)
        end
      end
    end
  end
  known = now
end

-- books already handed in to the library (needs b.quest)
local function scanQuests()
  local isDone = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
  if not isDone then return end
  for _, b in ipairs(BOOKS) do
    if b.quest and not ns.IsDone(b) and isDone(b.quest) then ns.SetDone(b, true, true) end
  end
end

-- Events (registered at PLAYER_LOGIN, once the saved state is loaded) ---
function ns.InitDetection()
  ns.db.itemIDs = ns.db.itemIDs or {}
  local f = CreateFrame("Frame")
  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:RegisterEvent("QUEST_TURNED_IN")
  f:SetScript("OnEvent", function(_, event, questID)
    if event == "QUEST_TURNED_IN" then
      for _, b in ipairs(BOOKS) do
        if b.quest == questID then ns.SetDone(b, true) end
      end
    else
      scanBags()
    end
  end)
  scanQuests()
  scanBags()
end
