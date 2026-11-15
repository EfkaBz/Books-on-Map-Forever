-- Books on map (Forever): round button on the world map (like Questie's) to show/hide the books.
-- Krowi_WorldMapButtons stacks it with the other addons' map buttons (Questie...)
local _, ns = ...
local L = ns.L

local button

local function updateTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_NONE")
  GameTooltip:ClearLines()
  GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0)
  GameTooltip:AddDoubleLine("Books on map (Forever)", ("%d/%d"):format(ns.CountDone(), #ns.BOOKS),
    1, 0.82, 0, 0.7, 0.7, 0.7)
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine(L["Left Click"], ns.db.hidden and L["Show the books"] or L["Hide the books"],
    0.4, 0.8, 1, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Right Click"], L["Open book list"], 0.4, 0.8, 1, 1, 1, 1)
  GameTooltip:Show()
end

-- books hidden: icon greyed and darkened (as Questie's when it's off)
function ns.RefreshMapButton()
  if not button then return end
  local off = ns.db.hidden and true or false
  button.Icon:SetDesaturated(off)
  button.IconOverlay:SetShown(off)
  if GameTooltip:IsShown() and GameTooltip:GetOwner() == button then updateTooltip(button) end
end

function ns.InitMapButton()
  local lib = LibStub and LibStub("Krowi_WorldMapButtons-1.4", true)
  if not lib or not WorldMapFrame then return end
  if lib.IsForever then lib.HasNoOverlay = false end -- (Forever: the modern overlay buttons, as Questie)

  button = lib:Add(nil, "Button")
  button:SetSize(32, 32)
  button:SetFrameStrata("HIGH")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(25, 25)
  bg:SetPoint("TOPLEFT", 2, -4)

  button.Icon = button:CreateTexture(nil, "ARTWORK")
  button.Icon:SetTexture(ns.ADDON_ICON)
  button.Icon:SetSize(20, 20)
  button.Icon:SetPoint("TOPLEFT", 7, -6)

  button.IconOverlay = button:CreateTexture(nil, "OVERLAY")
  button.IconOverlay:SetAllPoints(button.Icon)
  button.IconOverlay:SetColorTexture(0, 0, 0, 0.5)
  button.IconOverlay:Hide()

  local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")

  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  button.Refresh = function() end -- (called by the library on every map change)
  button:SetScript("OnClick", function(self, b)
    if b == "RightButton" then
      ns.ToggleOptions()
    else
      ns.db.hidden = not ns.db.hidden
      ns.Refresh()
    end
  end)
  button:SetScript("OnEnter", updateTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)

  ns.RefreshMapButton()
end
