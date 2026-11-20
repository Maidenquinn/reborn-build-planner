-- RBP minimap launcher. This module never sends gameplay commands.
-- Dedicated mouse handling avoids the 3.3.5a/native-wrapper drag-start issue.
local ADDON, ns = ...;
ns = ns or {};
local M = {};
ns.MinimapButton = M;
local RADIUS = 78;
local DEFAULT_X, DEFAULT_Y = 55, -55;
local MOVE_THRESHOLD = 4;

local function fitOnRim(x,y)
  local len = math.sqrt(x*x+y*y);
  if len < 1 then return DEFAULT_X,DEFAULT_Y end
  return x*RADIUS/len,y*RADIUS/len;
end

function M.Position(x,y)
  if not M.button or not Minimap then return end
  x,y=fitOnRim(x,y);
  M.button:ClearAllPoints();
  M.button:SetPoint("CENTER",Minimap,"CENTER",x,y);
  M.x,M.y=x,y;
end

local function cursorOffset()
  if type(GetCursorPosition)~="function" or not Minimap or not Minimap.GetCenter then return nil end
  local cx,cy=GetCursorPosition();
  local mx,my=Minimap:GetCenter();
  if not cx or not cy or not mx or not my then return nil end
  -- Cursor is in physical pixels, frame coordinates are in UI units.
  local scale=UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1;
  if scale<=0 then return nil end
  return cx/scale-mx,cy/scale-my;
end

local function save()
  if ns.storage and not ns.storage.readOnly then
    ns.storage:SetSetting("minimapPosition",{x=M.x,y=M.y});
  end
end

-- Called only during an active left-button hold, not every frame while idle.
function M.DragTick()
  if not M.dragging then return end
  local x,y=cursorOffset();
  if not x then return end
  if not M.moved then
    local dx=x-M.startX;
    local dy=y-M.startY;
    if dx*dx+dy*dy < MOVE_THRESHOLD*MOVE_THRESHOLD then return end
    M.moved=true;
  end
  M.Position(x,y);
end

function M.StopDrag()
  if not M.dragging then return end
  M.DragTick();
  M.dragging=false;
  if M.button then M.button:SetScript("OnUpdate",nil) end
  if M.moved then
    save();
    -- A mouse-up after movement must never toggle the planner.
    M.suppressClick=true;
  end
end

function M.Start()
  if M.button then return M.button end
  if type(CreateFrame)~="function" or not Minimap then return nil end
  local b=CreateFrame("Button","RBPMinimapButton",Minimap);
  b:SetSize(36,36);
  b:SetFrameStrata("DIALOG");
  b:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0)+30);
  b:EnableMouse(true);
  if b.EnableMouseWheel then b:EnableMouseWheel(true) end
  if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp","RightButtonUp") end

  -- One dedicated icon, with transparent edges. No stock tracking rings.
  b.emblem=b:CreateTexture(nil,"ARTWORK");
  b.emblem:SetSize(34,34);
  b.emblem:SetPoint("CENTER",b,"CENTER",0,0);
  b.emblem:SetTexture(ns.Theme.Media("ultimate_minimap"));
  if b.SetHighlightTexture then
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");
  end

  -- Keyboard/mouse fallback for clients that do not expose cursor coordinates
  -- or that consume the drag event through the custom minimap wrapper.
  -- Scroll the button to rotate it around the rim; this is independently
  -- usable even if mouse dragging is not supported by the native wrapper.
  b:SetScript("OnMouseWheel",function(_,delta)
    if not delta or delta==0 then return end
    local angle=(delta>0 and 1 or -1)*0.17;
    local x,y=M.x or DEFAULT_X,M.y or DEFAULT_Y;
    M.Position(x*math.cos(angle)-y*math.sin(angle),
               x*math.sin(angle)+y*math.cos(angle));
    save();
  end);
  b:SetScript("OnMouseDown",function(_,button)
    if button~="LeftButton" then return end
    local x,y=cursorOffset();
    if not x then return end
    M.dragging=true;
    M.moved=false;
    M.suppressClick=false;
    M.startX,M.startY=x,y;
    b:SetScript("OnUpdate",function()
      -- Some clients do not dispatch OnMouseUp to the original icon after
      -- dragging outside its bounds. Stop as soon as the left key is released.
      if type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then
        M.StopDrag();
      else
        M.DragTick();
      end
    end);
  end);
  b:SetScript("OnMouseUp",function(_,button)
    if button=="LeftButton" then M.StopDrag() end
  end);
  b:SetScript("OnHide",function() M.StopDrag() end);
  b:SetScript("OnClick",function(_,button)
    if button=="LeftButton" and M.suppressClick then M.suppressClick=false;return end
    if button=="RightButton" then
      if ns.Runtime and ns.Runtime.ready then ns.Runtime.ToggleHud() end
    elseif button=="LeftButton" and ns.ui and ns.ui.Toggle then
      ns.ui:Toggle();
    end
  end);
  b:SetScript("OnEnter",function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self,"ANCHOR_LEFT");
      GameTooltip:AddLine("Reborn Build Planner");
      GameTooltip:AddLine("Left-click: open RBP",.75,.82,1);
      GameTooltip:AddLine("Drag or scroll here: move icon",1,.82,.46);
      GameTooltip:AddLine("Right-click: toggle tracker",.75,.82,1);
      GameTooltip:Show();
    end
  end);
  b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end);
  M.button=b;
  local pos=ns.storage and ns.storage:GetSetting("minimapPosition");
  M.Position(pos and pos.x or DEFAULT_X,pos and pos.y or DEFAULT_Y);
  return b;
end
return M;
