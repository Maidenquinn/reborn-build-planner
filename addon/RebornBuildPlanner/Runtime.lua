-- Runtime: strictly read-only Reborn API integration. No OnUpdate/timers,
-- no SendAddonMessage or any automated card interaction.
local ADDON, ns = ...;
ns = ns or {};
local R = { ready=false, last=nil, callbacks=0, received={ spells=false, gear=false }, runKey=nil };
ns.Runtime = R;
local EVENTS = { "AZSSPELLS", "AZSSPELLTIP", "AZSGEAR", "AZSCARDS",
  "AZSCARDTIP", "AZSRUN", "AZSZONE", "AZSEND" };

-- The native globals start as empty tables. A table existing does NOT mean the
-- server has supplied a snapshot (notably during /reload). Track actual packets.
function R.Note(event)
  local runKey = type(AZS_API_RunId)=="function" and AZS_API_RunId() or
    (type(AZS_ZONE)=="table" and AZS_ZONE.run or nil);
  if runKey ~= R.runKey then
    R.runKey=runKey;
    R.received={ spells=false, gear=false };
  end
  if event=="AZSSPELLS" then R.received.spells=true end
  if event=="AZSGEAR" then R.received.gear=true end
end
function R.Capture()
  local phase = type(AZS_GetPhase)=="function" and AZS_GetPhase() or
    (type(AZS_RUN)=="table" and AZS_RUN.ph or nil);
  if type(AZS_ZONE)=="table" and tonumber(AZS_ZONE.hub)==1 then phase=nil end
  local running = phase=="playing" or phase=="choosing" or phase=="paused";
  return {
    inRun=running,
    phase=phase,
    spells=running and type(AZS_SPELLS)=="table" and AZS_SPELLS or nil,
    spellsKnown=running and R.received.spells and type(AZS_SPELLS)=="table" or false,
    gear=running and type(AZS_GEAR)=="table" and AZS_GEAR or nil,
    gearKnown=running and R.received.gear and type(AZS_GEAR)=="table" or false,
    cards=running and type(AZS_CARDS)=="table" and AZS_CARDS or nil,
    runId=type(AZS_ZONE)=="table" and AZS_ZONE.run or nil
  };
end
function R.Active()
  local cat=ns.catalog;local h=ns.storage;
  if not cat or not h or type(UnitClass)~="function" then return nil end
  local _,token=UnitClass("player");
  local cls=cat:NormalizeClass(token);
  if not cls then return nil end
  local id=h:GetActive(cls);
  return id and h:Get(id) or nil;
end
function R.Refresh()
  if not R.ready then return end
  local build=R.Active();
  local snapshot=R.Capture();
  R.last=snapshot;
  local phase=1; -- Phase changes require verified gameplay mapping; do not guess.
  local progress=build and ns.LiveTracker.Evaluate(build,phase,snapshot) or nil;
  local theme=ns.storage:GetSetting("trackerTheme") or "standard";
  if ns.TrackHUD and R.hud then
    if ns.storage:GetSetting("trackerEnabled") ~= false then
      ns.TrackHUD.Refresh(ns.TrackHUD,build,progress,ns.catalog,ns.Locale.lang,theme);
    else R.hud:Hide();end
    ns.TrackHUD.UpdateCards(ns.TrackHUD,build,snapshot,phase,theme);
  end
  R.progress=progress;
end
function R.ToggleTheme()
  if not ns.storage or ns.storage.readOnly then return false end
  local current=ns.storage:GetSetting("trackerTheme");
  local nextTheme=current=="elwynn" and "standard" or "elwynn";
  ns.storage:SetSetting("trackerTheme",nextTheme);
  R.Refresh();
  return nextTheme
end
function R.SetTheme(theme)
  if theme~="standard" and theme~="elwynn" then return false end
  if not ns.storage or ns.storage.readOnly then return false end
  local ok=ns.storage:SetSetting("trackerTheme",theme);
  if ok then R.Refresh() end
  return ok;
end
function R.ToggleHud()
  if not ns.storage or ns.storage.readOnly then return false end
  local value=not ns.storage:GetSetting("trackerEnabled");
  ns.storage:SetSetting("trackerEnabled",value);
  R.Refresh();
  return value;
end
function R.Start()
  if R.ready then return true end
  if type(AZS)~="table" or type(AZS.On)~="function" then return false end
  R.hud=ns.TrackHUD.New(function()R.ToggleTheme()end);
  if not R.hud then return false end
  R.ready=true;
  -- One explicit subscription to each documented API event.
  for _,event in ipairs(EVENTS) do
    AZS.On(event,function()
      R.callbacks=R.callbacks+1;
      R.Note(event);
      R.Refresh();
    end);
  end
  if ns.controller then ns.controller:Subscribe(function()R.Refresh()end) end
  if type(CreateFrame)=="function" then
    R.frame=CreateFrame("Frame");
    R.frame:RegisterEvent("PLAYER_ENTERING_WORLD");
    R.frame:SetScript("OnEvent",function()R.Refresh()end);
  end
  R.Refresh();
  return true
end
return R;
