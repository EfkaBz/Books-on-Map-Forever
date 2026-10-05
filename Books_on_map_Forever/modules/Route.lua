-- Books on map (Forever): optimized collection route (nearest neighbor + 2-opt, from the player's position)
local _, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

local CONTINENT_PENALTY = 20000 -- yards added for every boat/zeppelin trip between continents
local route = {}                -- { {book = b, loc = loc, cont = id, x = wx, y = wy}, ... }
local skipped = {}              -- book keys skipped for this session
local tracker

-- World position (continentID, x, y in yards) of a map position (0-1)
local function worldPos(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
  local cont, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
  if cont and pos then return cont, pos.x, pos.y end
end

local function playerPos()
  local mapID = C_Map.GetBestMapForUnit("player")
  local p = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if p then return worldPos(mapID, p.x, p.y) end
end

local function cost(a, b)
  local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
  if a.cont ~= b.cont then d = d + CONTINENT_PENALTY end
  return d
end

local function eligible(b)
  return not ns.IsDone(b) and not skipped[b.key]
end

-- optimized path (nearest neighbor + 2-opt) through the books of one set, from start
local function planSet(set, start)
  local cands = {}
  for _, b in ipairs(BOOKS) do
    if b.set == set and eligible(b) then
      -- every location of the book; a book is done once any of its locations is visited
      for _, loc in ipairs(b.locs) do
        local c, x, y = worldPos(loc[1], loc[2] / 100, loc[3] / 100)
        if c then cands[#cands + 1] = { book = b, loc = loc, cont = c, x = x, y = y } end
      end
    end
  end

  local path, used, cur = {}, {}, start
  while true do
    local best, bestD
    for _, c in ipairs(cands) do
      if not used[c.book] then
        local d = cost(cur, c)
        if not bestD or d < bestD then best, bestD = c, d end
      end
    end
    if not best then break end
    used[best.book] = true
    path[#path + 1] = best
    cur = best
  end

  -- 2-opt (open path)
  local n, improved, guard = #path, true, 0
  local function at(i) return i == 0 and start or path[i] end
  while improved and guard < 50 do
    improved, guard = false, guard + 1
    for i = 1, n - 1 do
      for j = i + 1, n do
        local a, b, c, d = at(i - 1), path[i], path[j], path[j + 1]
        local before = cost(a, b) + (d and cost(c, d) or 0)
        local after = cost(a, c) + (d and cost(b, d) or 0)
        if after < before - 0.5 then
          for k = 0, math.floor((j - i) / 2) do
            path[i + k], path[j - k] = path[j - k], path[i + k]
          end
          improved = true
        end
      end
    end
  end
  return path
end

-- Builds the route from the player's position: every book, lowest set first,
-- each set optimized and starting where the previous one ends
function ns.BuildRoute()
  wipe(route)
  local cont, px, py = playerPos()
  local cur = { cont = cont or -1, x = px or 0, y = py or 0 }
  for _, set in ipairs({ 1, 35, 45, 60 }) do
    for _, step in ipairs(planSet(set, cur)) do
      route[#route + 1] = step
      cur = step
    end
  end
  return route
end

function ns.GetRoute() return route end

-- step number of a book location in the route (for the map pins)
function ns.RouteStep(b, loc)
  if not ns.db.routeOn then return end
  for i, s in ipairs(route) do
    if s.book == b and s.loc == loc then return i end
  end
end

local function sendToTomTom()
  if not TomTom then print(ns.PREFIX .. L["TomTom is not installed."]) return end
  for i, s in ipairs(route) do
    TomTom:AddWaypoint(s.loc[1], s.loc[2] / 100, s.loc[3] / 100, { title = ("%d. %s"):format(i, s.book.name) })
  end
  print(ns.PREFIX .. L["%d waypoints sent to TomTom."]:format(#route))
end

-- Tracker (next book, distance, arrow) -----------------------------------
local function updateTracker()
  local s = route[1]
  if not s then
    tracker.name:SetText(L["Route finished!"])
    tracker.where:SetText(L["Every book has been collected."])
    tracker.dist:SetText("")
    tracker.arrow:Hide()
    return
  end
  tracker.name:SetText(("|cffffd100%d/%d|r  %s"):format(1, #route, s.book.name))
  tracker.where:SetText(("%s  |cff808080(%.1f, %.1f)|r"):format(s.loc[4], s.loc[2], s.loc[3]))
  local cont, px, py = playerPos()
  if cont and cont == s.cont then
    local dx, dy = s.x - px, s.y - py
    tracker.dist:SetText(L["%d yd"]:format(math.floor(math.sqrt(dx * dx + dy * dy))))
    local facing = GetPlayerFacing and GetPlayerFacing()
    if facing then
      tracker.arrow:SetRotation(math.atan2(dy, dx) - facing)
      tracker.arrow:Show()
    else
      tracker.arrow:Hide()
    end
  else
    tracker.dist:SetText(L["other continent"])
    tracker.arrow:Hide()
  end
end

local function smallButton(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(62, 20)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function createTracker()
  local f = CreateFrame("Frame", "BooksOnMapForeverRoute", UIParent, "BackdropTemplate")
  f:SetSize(270, 78)
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(0, 0, 0, 0.75)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.routePos = { p, rp, x, y }
  end)
  local pos = ns.db.routePos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", 0, -120) end

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(32, 32)
  icon:SetPoint("TOPLEFT", 8, -8)
  f.icon = icon

  f.arrow = f:CreateTexture(nil, "ARTWORK")
  f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.arrow:SetSize(32, 32)
  f.arrow:SetPoint("TOPRIGHT", -8, -6)

  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
  f.name:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)

  f.where = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.where:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
  f.where:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
  f.where:SetJustifyH("LEFT")
  f.where:SetWordWrap(false)

  f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.dist:SetPoint("TOPRIGHT", f.arrow, "BOTTOMRIGHT", 0, -1)
  f.dist:SetJustifyH("RIGHT")

  local skip = smallButton(f, L["Skip"], function()
    if route[1] then skipped[route[1].book.key] = true end
    ns.RefreshRoute(true)
  end)
  skip:SetPoint("BOTTOMLEFT", 8, 7)
  local recalc = smallButton(f, L["Recalc"], function() wipe(skipped); ns.RefreshRoute(true) end)
  recalc:SetPoint("LEFT", skip, "RIGHT", 4, 0)
  local tt = smallButton(f, "TomTom", sendToTomTom)
  tt:SetPoint("LEFT", recalc, "RIGHT", 4, 0)
  local close = smallButton(f, "X", function() ns.ToggleRoute(false) end)
  close:SetWidth(24)
  close:SetPoint("BOTTOMRIGHT", -8, 7)

  local elapsed = 0
  f:SetScript("OnUpdate", function(_, e)
    elapsed = elapsed + e
    if elapsed < 0.1 then return end
    elapsed = 0
    updateTracker()
  end)
  return f
end

-- rebuild = recompute the order from the current position
function ns.RefreshRoute(rebuild)
  if not ns.db or not ns.db.routeOn then return end
  tracker = tracker or createTracker()
  if rebuild or not route[1] or ns.IsDone(route[1].book) then ns.BuildRoute() end
  local s = route[1]
  tracker.icon:SetTexture(s and s.book.icon and ("Interface\\Icons\\" .. s.book.icon) or ns.ICON)
  tracker:Show()
  updateTracker()
  ns.RefreshMap()
end

function ns.ToggleRoute(on)
  if on == nil then on = not ns.db.routeOn end
  ns.db.routeOn = on or nil
  if on then
    ns.RefreshRoute(true)
    print(ns.PREFIX .. L["route: %d books, lowest level first."]:format(#route))
  else
    wipe(route)
    if tracker then tracker:Hide() end
    ns.RefreshMap()
  end
end

function ns.PrintRoute()
  if not ns.db.routeOn then ns.ToggleRoute(true) end
  for i, s in ipairs(route) do
    print(("|cffffd100%2d.|r %s - %s (%.1f, %.1f)"):format(i, s.book.name, s.loc[4], s.loc[2], s.loc[3]))
  end
end

function ns.SendRouteToTomTom() sendToTomTom() end

function ns.InitRoute()
  if ns.db.routeOn then ns.RefreshRoute(true) end
end
