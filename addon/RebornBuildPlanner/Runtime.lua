-- Runtime: strictly read-only Reborn API integration. No OnUpdate/timers,
-- no SendAddonMessage or any automated card interaction.
local ADDON, ns = ...;
ns = ns or {};
local R = { ready=false, last=nil, callbacks=0, received={ spells=false, gear=false, cards=false, spellTips=false }, runKey=nil, stage=1, stageRun=nil };
ns.Runtime = R;
R.bans={};R.pendingBan=nil;R.banRun=nil;
-- Use the same stable server run identity for commands, packets and reloads.
-- The API's client-local fallback may change after a reload, so prefer zone.run.
local function currentRun()
  local id=type(AZS_ZONE)=="table" and AZS_ZONE.run or nil;
  if id==nil and type(AZS_API_RunId)=="function" then id=AZS_API_RunId() end
  return id~=nil and tostring(id) or nil;
end
local function restoreBans(id)
  if not id or not ns.storage then return {} end
  local saved=ns.storage:GetSetting("captureBanJournal");
  if type(saved)=="table" and saved.run==id and type(saved.spells)=="table" then
    local result={};
    for key,value in pairs(saved.spells) do
      if type(key)=="string" and value==true then result[key]=true end
    end
    return result;
  end
  return {};
end
local function saveBans()
  if ns.storage and not ns.storage.readOnly and R.banRun then
    local copy={};
    for key,enabled in pairs(R.bans) do if enabled==true then copy[key]=true end end
    ns.storage:SetSetting("captureBanJournal",{run=R.banRun,spells=copy});
  end
end
function R.SyncBanRun()
  local id=currentRun();
  if not id then return end -- never erase a known run due to a transient nil
  if id~=R.banRun then
    R.banRun=id;
    R.bans=restoreBans(id);
    R.pendingBan=nil;
  end
end
-- Observe the player's actual command, never send a ban command ourselves.
-- Confirm its success only from the new card count provided by the server.
function R.ObserveBanishCommand(prefix,command)
  if prefix~="AZSCMD" then return end
  local index=tonumber(string.match(tostring(command or ""),"^banish (%d+)$"));
  if not index then return end
  R.SyncBanRun();
  local offer=type(AZS_CARDS)=="table" and AZS_CARDS or nil;
  local card=offer and type(offer.cards)=="table" and offer.cards[index];
  local id=currentRun();
  if not id or not offer or offer.kind~="spell" or type(card)~="table" or
     type(card.key)~="string" or (tonumber(offer.bn) or 0)<=0 then return end
  R.pendingBan={run=id,key=card.key,before=tonumber(offer.bn)};
end
function R.ConfirmBanish()
  local pending=R.pendingBan;
  if not pending then return end
  R.SyncBanRun();
  local id=currentRun();
  local offer=type(AZS_CARDS)=="table" and AZS_CARDS or nil;
  if not id or id~=pending.run then R.pendingBan=nil;return end
  -- Ignore unrelated card packets rather than clearing a pending confirmation.
  if not offer or offer.kind~="spell" or tonumber(offer.bn)==nil then return end
  R.pendingBan=nil;
  if tonumber(offer.bn)==pending.before-1 then
    R.bans[pending.key]=true;
    saveBans();
  end
end
local EVENTS = { "AZSSPELLS", "AZSSPELLTIP", "AZSGEAR", "AZSCARDS",
  "AZSCARDTIP", "AZSRUN", "AZSZONE", "AZSEND" };

-- The native globals start as empty tables. A table existing does NOT mean the
-- server has supplied a snapshot (notably during /reload). Track actual packets.
function R.Note(event)
  local runKey=currentRun();
  if runKey and runKey~=R.runKey then
    R.runKey=runKey;
    R.received={ spells=false, gear=false, cards=false, spellTips=false };
    R.SyncBanRun();
  end
  if event=="AZSSPELLS" then R.received.spells=true end
  if event=="AZSGEAR" then R.received.gear=true end
  if event=="AZSSPELLTIP" then R.received.spellTips=true end
  if event=="AZSCARDS" then R.ConfirmBanish();R.received.cards=true end
end
function R.Capture()
  R.SyncBanRun();
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
    nativeNames=type(AZS_L)=="table" and AZS_L or nil,
    gearKnown=running and R.received.gear and type(AZS_GEAR)=="table" or false,
    spellTips=running and type(AZS_SPELLTIPS)=="table" and AZS_SPELLTIPS or nil,
    spellTipsKnown=running and R.received.spellTips and type(AZS_SPELLTIPS)=="table" or false,
    banned=running and R.bans or {},
    bannedKnown=running and R.banRun~=nil or false,
    bansComplete=false, -- no authoritative historic banned-spell API exists
    cards=running and R.received.cards and type(AZS_CARDS)=="table" and AZS_CARDS or nil,
    gold=running and type(AZS_RUN)=="table" and tonumber(AZS_RUN.gold) or nil,
    runId=type(AZS_ZONE)=="table" and AZS_ZONE.run or nil
  };
end
function R.PlayerClass()
  if not ns.catalog or type(UnitClass)~="function" then return nil end
  local _,token=UnitClass("player");
  return ns.catalog:NormalizeClass(token);
end
function R.BuildOptions()
  if not ns.storage then return {} end
  local cls=R.PlayerClass();if not cls then return {} end
  local active=ns.storage:GetActive(cls);
  local out={};
  for _,record in ipairs(ns.storage:List(cls)) do
    if record.clean then
      out[#out+1]={id=record.id,name=record.name,active=record.id==active};
    end
  end
  return out;
end
function R.SelectBuild(id)
  if not ns.storage or ns.storage.readOnly then return false end
  local cls=R.PlayerClass();
  if not cls then return false end
  local ok=ns.storage:SetActive(cls,id);
  if ok then R.Refresh() end
  return ok and true or false;
end
function R.ToggleCompact()
  if not ns.storage or ns.storage.readOnly then return false end
  local nextValue=ns.storage:GetSetting("trackerCompact")~=true;
  local ok=ns.storage:SetSetting("trackerCompact",nextValue);
  if ok then R.Refresh() end
  return ok and nextValue or false;
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
function R.HookCardsFrame()
  -- Native cards may become visible after AZSCARDS is sent. Hook show/hide,
  -- instead of polling every frame or replacing the game's existing scripts.
  local frame=AZSCardsFrame;
  if not frame or type(frame.HookScript)~="function" or R.cardsHooked==frame then return end
  R.cardsHooked=frame;
  frame:HookScript("OnShow",function()R.Refresh()end);
  frame:HookScript("OnHide",function()R.Refresh()end);
end
R.profile={calls=0,totalMs=0,maxMs=0};
R.profileEnabled=false;
function R.ResetProfile()
  R.profile={calls=0,totalMs=0,maxMs=0};
end
function R.ProfileSummary()
  local p=R.profile;
  return {calls=p.calls,totalMs=p.totalMs,maxMs=p.maxMs,
    averageMs=p.calls>0 and p.totalMs/p.calls or 0,
    callbacks=R.callbacks,enabled=R.profileEnabled};
end
function R.Refresh()
  if not R.ready then return end
  local started=R.profileEnabled and type(debugprofilestop)=="function" and debugprofilestop() or nil
  local build=R.Active();
  local snapshot=R.Capture();
  R.HookCardsFrame();
  R.last=snapshot;
  if snapshot.runId and R.stageRun ~= tostring(snapshot.runId) then
    R.stageRun=tostring(snapshot.runId);
    R.stage=1; -- new run: do not carry last run's manually selected phase
  end
  local phase=R.stage or 1; -- explicit selection, no invented mapping from game phase
  local progress=build and ns.LiveTracker.Evaluate(build,phase,snapshot,ns.catalog,ns.Locale.lang) or nil;
  if progress then progress.stage=phase; progress.stageMax=4 end
  local theme=ns.storage:GetSetting("trackerTheme") or "standard";
  ns.TrackHUD.compact=ns.storage:GetSetting("trackerCompact")==true;
  ns.TrackHUD.SetBuildOptions(ns.TrackHUD,R.BuildOptions());
  if ns.TrackHUD and R.hud then
    if ns.storage:GetSetting("trackerEnabled") ~= false then
      ns.TrackHUD.Refresh(ns.TrackHUD,build,progress,ns.catalog,ns.Locale.lang,theme,snapshot);
      local alpha=ns.storage:GetSetting("trackerOpacity");
      if type(alpha)~="number" then alpha=1 end
      ns.TrackHUD.SetBackgroundOpacity(ns.TrackHUD,alpha,theme);
    else R.hud:Hide();end
    ns.TrackHUD.UpdateCards(ns.TrackHUD,build,snapshot,phase,theme,ns.catalog,ns.Locale.lang);
  end
  R.progress=progress;
  if started then
    local delta=math.max(0,debugprofilestop()-started);
    local p=R.profile;
    p.calls=p.calls+1;p.totalMs=p.totalMs+delta;
    if delta>p.maxMs then p.maxMs=delta end
  end
end
function R.CycleStage()
  R.stage=R.stage%4+1;
  R.Refresh();
  return R.stage;
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
  local value=(ns.storage:GetSetting("trackerEnabled") == false);
  ns.storage:SetSetting("trackerEnabled",value);
  R.Refresh();
  return value;
end
function R.Start()
  if R.ready then return true end
  if type(AZS)~="table" or type(AZS.On)~="function" then return false end
  R.hud=ns.TrackHUD.New(function()R.ToggleTheme()end,function()R.CycleStage()end,
    function(id)R.SelectBuild(id)end,function()R.ToggleCompact()end,
    function() if ns.ui and ns.ui.Show then ns.ui:Show() end end);
  if not R.hud then return false end
  R.ready=true;
  if type(hooksecurefunc)=="function" and type(SendAddonMessage)=="function" then
    hooksecurefunc("SendAddonMessage",function(prefix,command)R.ObserveBanishCommand(prefix,command)end);
  end
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
