-- RBP minimap launcher: follow the native Azeroth Stats drag convention.
-- Preserve the existing minimapPosition SavedVariables shape for beta users.
-- Never issues gameplay commands; FieldKit may adjust our CENTER anchor at runtime.
local ADDON, ns = ...;
ns = ns or {};
local M = {};
ns.MinimapButton = M;

local RADIUS = 80;
local DEFAULT_X, DEFAULT_Y = 55, -55;

local function fitOnRim(x, y)
  x, y = tonumber(x), tonumber(y);
  if not x or not y or x ~= x or y ~= y then return DEFAULT_X, DEFAULT_Y end
  local len = math.sqrt(x*x + y*y);
  if len < 1 then return DEFAULT_X, DEFAULT_Y end
  return x*RADIUS/len, y*RADIUS/len;
end

function M.Position(x, y)
  if not M.button or not Minimap then return end
  x, y = fitOnRim(x, y);
  M.x, M.y = x, y;
  M.button:ClearAllPoints();
  M.button:SetPoint("CENTER", Minimap, "CENTER", x, y);
end

local function cursorOffset()
  if type(GetCursorPosition) ~= "function" or not Minimap or not Minimap.GetCenter then return nil end
  local cx, cy = GetCursorPosition();
  local mx, my = Minimap:GetCenter();
  local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale();
  if type(scale) ~= "number" or scale <= 0 or scale ~= scale then return nil end
  if not cx or not cy or not mx or not my then return nil end
  return cx/scale-mx, cy/scale-my;
end

local function save()
  if ns.storage and not ns.storage.readOnly then
    ns.storage:SetSetting("minimapPosition", { x=M.x, y=M.y });
  end
end

function M.DragTick()
  if not M.dragging then return end
  local x, y = cursorOffset();
  if not x then return end
  if x*x+y*y < 1 then return end
  local oldX, oldY = M.x, M.y;
  M.Position(x, y);
  if not oldX or math.abs(M.x-oldX)>0.01 or math.abs(M.y-oldY)>0.01 then
    M.moved = true;
  end
end

function M.StopDrag()
  if not M.dragging then return end
  M.DragTick();
  M.dragging = false;
  if M.button then M.button:SetScript("OnUpdate", nil) end
  if M.moved then
    save();
    M.suppressClick = true;
  end
end

function M.Start()
  if M.button then return M.button end
  if type(CreateFrame) ~= "function" or not Minimap then return nil end
  local b = CreateFrame("Button", "RBPMinimapButton", Minimap);
  b:SetSize(30, 30);
  b:SetFrameStrata("MEDIUM");
  b:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0)+2);
  b:EnableMouse(true);
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
  b:RegisterForDrag("LeftButton");

  -- Dedicated, packaged original compass seal. A stock game texture may be
  -- missing in this client (the red question-mark reported by the tester).
  -- The emblem already contains its own subtle border: no second ring.
  b.emblem = b:CreateTexture(nil, "ARTWORK");
  b.emblem:SetPoint("CENTER", b, "CENTER", 0, 0);
  b.emblem:SetSize(30, 30);
  b.emblem:SetTexture(ns.Theme.Media("ultimate_minimap"));

  b:SetScript("OnDragStart", function()
    M.dragging = true;
    M.moved = false;
    M.suppressClick = false;
    -- Only tick while actively dragging; never run a permanent OnUpdate.
    b:SetScript("OnUpdate", function()
      if type(IsMouseButtonDown) == "function" and not IsMouseButtonDown("LeftButton") then
        M.StopDrag();
      else
        M.DragTick();
      end
    end);
  end);
  b:SetScript("OnDragStop", function() M.StopDrag() end);
  -- A client which drops OnDragStop when the pointer leaves the icon still
  -- finishes the drag on mouse release when it dispatches OnMouseUp.
  b:SetScript("OnMouseUp", function(_, mouse)
    if mouse == "LeftButton" then M.StopDrag() end
  end);
  b:SetScript("OnHide", function() M.StopDrag() end);
  b:SetScript("OnClick", function(_, mouse)
    if mouse == "LeftButton" then
      if M.suppressClick then M.suppressClick=false; return end
      if ns.ui and ns.ui.Toggle then ns.ui:Toggle() end
    elseif mouse == "RightButton" then
      if ns.Runtime and ns.Runtime.ready then ns.Runtime.ToggleHud() end
    end
  end);
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT");
    GameTooltip:AddLine("Reborn Build Planner");
    GameTooltip:AddLine("Left-click: open RBP", .75, .82, 1);
    GameTooltip:AddLine("Left-drag: move around minimap", 1, .82, .46);
    GameTooltip:AddLine("Right-click: toggle tracker", .75, .82, 1);
    GameTooltip:Show();
  end);
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end);

  M.button = b;
  local pos = ns.storage and ns.storage:GetSetting("minimapPosition");
  M.Position(pos and pos.x or DEFAULT_X, pos and pos.y or DEFAULT_Y);
  return b;
end
return M;
