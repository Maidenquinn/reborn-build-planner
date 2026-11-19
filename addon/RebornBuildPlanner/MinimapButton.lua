-- Reborn Build Planner minimap launcher (WoW 3.3.5a).
-- Pure UI: left-click opens the planner; right-click toggles the optional HUD.
-- Never hooks native minimap clicks or sends a gameplay command.
local ADDON, ns = ...;
ns = ns or {};
local M = {};
ns.MinimapButton = M;

function M.Start()
  if M.button then return M.button end
  if type(CreateFrame) ~= "function" or not Minimap then return nil end
  local b = CreateFrame("Button", "RBPMinimapButton", Minimap);
  b:SetWidth(30); b:SetHeight(30);
  b:SetFrameStrata("MEDIUM"); b:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0) + 8);
  b:SetPoint("CENTER", Minimap, "CENTER", 58, -58);
  b:SetNormalTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
  b.icon = b:CreateTexture(nil, "ARTWORK");
  b.icon:SetWidth(19); b.icon:SetHeight(19);
  b.icon:SetPoint("CENTER", b, "CENTER", 0, 0);
  b.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01");
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
  b:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      if ns.Runtime and ns.Runtime.ready then ns.Runtime.ToggleHud() end
    elseif ns.ui and ns.ui.Toggle then
      ns.ui:Toggle()
    end
  end);
  b:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT");
      GameTooltip:AddLine("Reborn Build Planner");
      GameTooltip:AddLine("Left-click: open or close RBP", .75,.82,1);
      GameTooltip:AddLine("Right-click: show or hide the tracker", .75,.82,1);
      GameTooltip:Show();
    end
  end);
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end);
  M.button=b;
  return b;
end
return M;
