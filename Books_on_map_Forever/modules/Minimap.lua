-- Books on map (Forever): minimap button
local _, ns = ...
local L = ns.L

local btn

local function place()
  local a = math.rad(ns.db.minimapAngle or 200)
  local r = (Minimap:GetWidth() / 2) + 10
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.UpdateMinimapButton()
  if btn then btn:SetShown(not ns.db.hideMinimap) end
end

function ns.InitMinimapButton()
  btn = CreateFrame("Button", "BooksOnMapForeverMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ns.ADDON_ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local s = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      ns.ToggleOptions()
    else
      ns.db.hidden = not ns.db.hidden
      ns.Refresh()
    end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Books on map (Forever)")
    GameTooltip:AddLine(L["Collected: %d/%d"]:format(ns.CountDone(), #ns.BOOKS), 1, 1, 1)
    GameTooltip:AddLine(L["Left-click: open book list"], 0.5, 1, 0.5)
    GameTooltip:AddLine(L["Right-click: toggle map icons"], 0.5, 1, 0.5)
    GameTooltip:AddLine(L["Drag: move button"], 0.5, 1, 0.5)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  place()
  ns.UpdateMinimapButton()
end
