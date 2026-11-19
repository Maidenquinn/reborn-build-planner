-- RBP minimap launcher for WoW 3.3.5a: original fantasy crest and movable position.
-- Left click opens the planner; right click toggles the tracker. Drag with left mouse
-- to reposition around the minimap. Position persists in our existing SavedVariables.
local ADDON, ns = ...;
ns = ns or {};
local M = {};
ns.MinimapButton = M;
local RADIUS = 78;
local DEFAULT_X, DEFAULT_Y = 55, -55;

local function fitOnRim(x, y)
  local length = math.sqrt(x*x + y*y);
  if length < 1 then return DEFAULT_X, DEFAULT_Y end
  return x * RADIUS / length, y * RADIUS / length;
end

function M.Position(x, y)
  local b = M.button;
  if not b or not Minimap then return end
  x, y = fitOnRim(x, y);
  b:ClearAllPoints();
  b:SetPoint("CENTER", Minimap, "CENTER", x, y);
  M.x, M.y = x, y;
end

function M.EndDrag()
  local b = M.button;
  if not b then return end
  b:StopMovingOrSizing();
  local mx, my = Minimap and Minimap.GetCenter and Minimap:GetCenter();
  local bx, by = b.GetCenter and b:GetCenter();
  local scale = Minimap and Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1;
  if mx and my and bx and by and scale > 0 then
    M.Position((bx-mx)/scale, (by-my)/scale);
    if ns.storage and not ns.storage.readOnly then
      ns.storage:SetSetting("minimapPosition", {x=M.x, y=M.y});
    end
  else
    M.Position(M.x or DEFAULT_X, M.y or DEFAULT_Y);
  end
end

function M.Start()
  if M.button then return M.button end
  if type(CreateFrame) ~= "function" or not Minimap then return nil end
  local b = CreateFrame("Button", "RBPMinimapButton", Minimap);
  b:SetSize(32, 32);
  b:SetFrameStrata("MEDIUM");
  b:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0)+8);
  b:EnableMouse(true);
  b:SetMovable(true);
  b:RegisterForDrag("LeftButton");

  -- The original parchment icon was a generic quest note. Use the same
  -- moonlit gold crest as the planner title bar, framed as a minimap badge.
  b.disc = b:CreateTexture(nil, "BACKGROUND");
  b.disc:SetSize(26, 26);
  b.disc:SetPoint("CENTER", b, "CENTER", 0, 0);
  b.disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background");
  b.crest = b:CreateTexture(nil, "ARTWORK");
  b.crest:SetSize(24, 24);
  b.crest:SetPoint("CENTER", b, "CENTER", 0, 0);
  b.crest:SetTexture(ns.Theme.Media("ultimate_crest"));
  b.ring = b:CreateTexture(nil, "OVERLAY");
  b.ring:SetSize(52, 52);
  b.ring:SetPoint("CENTER", b, "CENTER", 0, 0);
  b.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
  if b.SetHighlightTexture then
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");
  end
  if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  b:SetScript("OnDragStart", function(self) self:StartMoving() end);
  b:SetScript("OnDragStop", function() M.EndDrag() end);
  b:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      if ns.Runtime and ns.Runtime.ready then ns.Runtime.ToggleHud() end
    elseif ns.ui and ns.ui.Toggle then ns.ui:Toggle() end
  end);
  b:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT");
      GameTooltip:AddLine("Reborn Build Planner");
      GameTooltip:AddLine("Left-click: open or close RBP", .75,.82,1);
      GameTooltip:AddLine("Right-click: show or hide the tracker", .75,.82,1);
      GameTooltip:AddLine("Left-drag: move around the minimap", 1,.82,.46);
      GameTooltip:Show();
    end
  end);
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end);
  M.button = b;
  local saved = ns.storage and ns.storage:GetSetting("minimapPosition");
  M.Position(saved and saved.x or DEFAULT_X, saved and saved.y or DEFAULT_Y);
  return b;
end
return M;
