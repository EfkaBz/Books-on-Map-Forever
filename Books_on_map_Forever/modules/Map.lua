-- Books on map (Forever): world map pins
local _, ns = ...
local L = ns.L
local BOOKS, CONTINENTS = ns.BOOKS, ns.CONTINENTS

ns.DEFAULT_PIN_SIZE = 20
local pins, pinPool = {}, {}
local lines, linePool = {}, {}

local function releaseLines()
  for i = #lines, 1, -1 do
    lines[i]:Hide()
    linePool[#linePool + 1] = lines[i]
    lines[i] = nil
  end
end

-- route segment between two canvas points
local function drawLine(canvas, x1, y1, x2, y2, thickness)
  local ln = table.remove(linePool)
  if not ln then
    ln = canvas:CreateLine(nil, "OVERLAY")
    ln:SetColorTexture(0.3, 0.8, 1, 0.8)
  end
  ln:SetThickness(thickness)
  ln:SetStartPoint("TOPLEFT", canvas, x1, -y1)
  ln:SetEndPoint("TOPLEFT", canvas, x2, -y2)
  ln:Show()
  lines[#lines + 1] = ln
end

-- position (0-1) of a book location on the displayed map, or nil
local function project(loc, mapID, onContinent)
  local x, y = loc[2] / 100, loc[3] / 100
  if loc[1] == mapID then return x, y end
  if onContinent then
    local left, right, top, bottom = C_Map.GetMapRectOnMap(loc[1], mapID)
    if left and right ~= left then
      return left + x * (right - left), top + y * (bottom - top)
    end
  end
end

local function acquirePin(canvas)
  local p = table.remove(pinPool)
  if not p then
    p = CreateFrame("Button", nil, canvas)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p.num = p:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    p.num:SetPoint("BOTTOMRIGHT", 4, -2)
    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.book.name, 1, 0.82, 0)
      GameTooltip:AddLine(("%s  (%.1f, %.1f)"):format(self.loc[4], self.loc[2], self.loc[3]), 1, 1, 1)
      if self.step then GameTooltip:AddLine(L["Route step %d"]:format(self.step), 0.4, 0.8, 1) end
      GameTooltip:AddLine(L["Books: %d/%d"]:format(ns.CountDone(), #BOOKS), 0.7, 0.7, 0.7)
      GameTooltip:AddLine(L["Shift-click: mark as collected"], 0.5, 1, 0.5)
      if TomTom then GameTooltip:AddLine(L["Right-click: TomTom waypoint"], 0.5, 1, 0.5) end
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        if TomTom then
          TomTom:AddWaypoint(self.loc[1], self.loc[2] / 100, self.loc[3] / 100, { title = self.book.name })
        end
      elseif IsShiftKeyDown() then
        GameTooltip:Hide()
        ns.SetDone(self.book, true)
      end
    end)
  end
  p:SetParent(canvas)
  return p
end

local function releasePins()
  for i = #pins, 1, -1 do
    local p = pins[i]
    p:Hide()
    p:ClearAllPoints()
    pins[i] = nil
    pinPool[#pinPool + 1] = p
  end
end

function ns.RefreshMap()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  releasePins()
  releaseLines()
  if ns.db.hidden then return end
  local mapID = WorldMapFrame:GetMapID()
  if not mapID then return end
  local canvas = WorldMapFrame:GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:GetCanvasScale() or 1
  if not scale or scale <= 0 then scale = 1 end
  local onContinent = CONTINENTS[mapID]
  local size = (ns.db.pinSize or ns.DEFAULT_PIN_SIZE) / scale * (onContinent and 0.7 or 1)

  for _, b in ipairs(BOOKS) do
    if not ns.IsDone(b) then
      for _, loc in ipairs(b.locs) do
        local x, y = project(loc, mapID, onContinent)
        if x then
          local p = acquirePin(canvas)
          p.book, p.loc = b, loc
          p.step = ns.RouteStep and ns.RouteStep(b, loc)
          p.num:SetText(p.step or "")
          p.num:SetScale(1 / scale)
          p.tex:SetTexture(b.icon and ("Interface\\Icons\\" .. b.icon) or ns.ICON)
          p:SetSize(size, size)
          p:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
          p:SetFrameLevel(canvas:GetFrameLevel() + 2000)
          p:Show()
          pins[#pins + 1] = p
        end
      end
    end
  end

  -- route lines between consecutive steps visible on this map
  if ns.db.routeOn and ns.GetRoute then
    local prevX, prevY
    for _, s in ipairs(ns.GetRoute()) do
      local x, y = project(s.loc, mapID, onContinent)
      if x and prevX then drawLine(canvas, prevX * w, prevY * h, x * w, y * h, 3 / scale) end
      prevX, prevY = x, y
    end
  end
end

function ns.InitMap()
  hooksecurefunc(WorldMapFrame, "OnMapChanged", ns.Refresh)
  WorldMapFrame:HookScript("OnShow", ns.Refresh)
  if WorldMapFrame.OnCanvasScaleChanged then
    hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", ns.Refresh)
  end
end
