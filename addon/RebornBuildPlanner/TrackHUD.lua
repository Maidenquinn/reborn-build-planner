-- Read-only compact in-game build tracker. No polling, no native card interaction.
-- Standard follows FieldKit's Naxxramas family; Elwynn follows FieldKit's
-- forest/gold family. FieldKit is optional: own artwork remains the fallback.
local ADDON, ns = ...;
ns = ns or {};
local H = {};
ns.TrackHUD = H;
local WHITE = "Interface\\Buttons\\WHITE8X8";
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border";
local FIELDKIT = "Interface\\AddOns\\AzerothFieldKit\\media\\ReferenceHUD\\";
local THEMES = {
  standard = { bg={0.025,0.045,0.065,0.96}, edge={0.39,0.55,0.64,1}, gold={0.77,0.87,0.91}, mute={0.65,0.73,0.78},
    art="naxx_card_body_v9.tga" },
  elwynn = { bg={0.035,0.075,0.055,0.96}, edge={0.76,0.56,0.24,1}, gold={1,0.82,0.41}, mute={0.78,0.83,0.70},
    art="elwynn_card_body_v9.tga" },
};
local WIDTH, HEIGHT = 204, 222;
local function label(parent, font, size, x, y, width)
  local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);
  f:SetWidth(width);f:SetHeight(size+3);f:SetJustifyH("LEFT");
  return f;
end
local function trunc(s,n)
  s=tostring(s or "");
  if #s<=n then return s end
  return string.sub(s,1,n-3).."...";
end
local function surface(frame, theme)
  local c=THEMES[theme] or THEMES.standard;
  frame:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=10,
    insets={left=2,right=2,top=2,bottom=2}});
  frame:SetBackdropColor(unpack(c.bg));
  frame:SetBackdropBorderColor(unpack(c.edge));
end
local function iconTexture(record)
  local icon=record and record.icon;
  if type(icon)~="string" or icon=="" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  if string.find(icon,"\\",1,true) then return icon end
  return "Interface\\Icons\\"..icon;
end
local function row(parent, y, compact)
  local r=CreateFrame("Frame",nil,parent);
  r:SetSize(WIDTH-12,compact and 14 or 16);
  r:SetPoint("TOPLEFT",parent,"TOPLEFT",6,-y);
  r.icon=r:CreateTexture(nil,"ARTWORK");
  r.icon:SetSize(compact and 12 or 14,compact and 12 or 14);
  r.icon:SetPoint("LEFT",r,"LEFT",2,0);
  r.name=label(r,"GameFontHighlightSmall",compact and 9 or 9,20,2,124);
  r.state=label(r,"GameFontNormalSmall",9,146,2,43);
  r.state:SetJustifyH("RIGHT");
  return r;
end
function H.New(onTheme,onStage)
  if type(CreateFrame)~="function" or not UIParent then return nil end
  local f=CreateFrame("Frame","RBPTrackerHUD",UIParent);
  f:SetSize(WIDTH,HEIGHT);
  f:SetFrameStrata("HIGH");f:SetFrameLevel(75);
  f:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-26,180);
  f:SetClampedToScreen(true);f:SetMovable(true);
  f.art=f:CreateTexture(nil,"BACKGROUND");
  f.art:SetPoint("TOPLEFT",f,"TOPLEFT",3,-3);
  f.art:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-3,3);
  f.art:SetTexture(ns.Theme.Media("ultimate_panel"));f.art:SetAlpha(0.19);
  f:EnableMouse(true);f:RegisterForDrag("LeftButton");
  f:SetScript("OnDragStart",function(self)self:StartMoving()end);
  f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end);
  f.title=label(f,"GameFontNormal",10,8,6,135);
  f.counter=label(f,"GameFontHighlightSmall",9,144,7,29);
  f.counter:SetJustifyH("RIGHT");
  f.themeButton=CreateFrame("Button",nil,f);
  f.themeButton:SetSize(28,16);
  f.themeButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-3,-2);
  f.themeButton.text=label(f.themeButton,"GameFontHighlightSmall",9,1,2,27);
  f.themeButton:SetScript("OnClick",function()if onTheme then onTheme()end end);
  f.stageButton=CreateFrame("Button",nil,f);
  f.stageButton:SetSize(WIDTH-12,15);
  f.stageButton:SetPoint("TOPLEFT",f,"TOPLEFT",6,-20);
  f.stageButton.text=label(f.stageButton,"GameFontHighlightSmall",9,1,1,WIDTH-15);
  f.stageButton:SetScript("OnClick",function()if onStage then onStage()end end);
  f.rule=f:CreateTexture(nil,"ARTWORK");f.rule:SetTexture(WHITE);
  f.rule:SetHeight(1);
  f.rule:SetPoint("TOPLEFT",f,"TOPLEFT",7,-37);
  f.rule:SetPoint("TOPRIGHT",f,"TOPRIGHT",-7,-37);
  f.rows={};
  for i=1,6 do f.rows[i]=row(f,40+(i-1)*16,false) end
  f.gear=label(f,"GameFontNormalSmall",9,8,139,152);
  f.gearCount=label(f,"GameFontHighlightSmall",9,153,139,41);
  f.gearCount:SetJustifyH("RIGHT");
  f.jewels={};
  for i=1,5 do f.jewels[i]=row(f,153+(i-1)*13,true) end
  f.info=label(f,"GameFontHighlightSmall",9,8,211,188);
  f:Hide();H.frame=f;return f;
end
function H.Refresh(self,build,progress,catalog,lang,theme)
  local f=self.frame;if not f then return end
  if not build or not progress or not progress.inRun then f:Hide();return end
  theme=THEMES[theme] and theme or "standard";
  local c=THEMES[theme];surface(f,theme);
  if type(IsAddOnLoaded)=="function" and IsAddOnLoaded("AzerothFieldKit") then
    f.art:SetTexture(FIELDKIT..c.art);
    f.art:SetAlpha(0.65);
  else
    f.art:SetTexture(ns.Theme.Media("ultimate_panel"));
    f.art:SetAlpha(0.22);
  end
  f.rule:SetVertexColor(unpack(c.edge));
  f.title:SetText(trunc(build.name,19));f.title:SetTextColor(unpack(c.gold));
  f.counter:SetText(tostring(progress.achieved or 0).."/"..tostring(progress.total or 0));
  f.counter:SetTextColor(unpack(c.mute));
  f.themeButton.text:SetText(theme=="elwynn" and "ELW" or "STD");
  f.themeButton.text:SetTextColor(unpack(c.gold));
  local fr=lang=="frFR";
  local stage=progress.stage or 1;
  local phaseName=build.phases and build.phases[stage] and build.phases[stage].label;
  if not phaseName or phaseName=="" then
    phaseName=ns.Locale.T(ns.BuildModel.DEFAULT_LABELS[stage] or "Stage");
  end
  f.stageButton.text:SetText((fr and "Étape " or "Stage ")..stage.."/4 · "..trunc(phaseName,22).." >");
  f.stageButton.text:SetTextColor(unpack(c.gold));
  for i,r in ipairs(f.rows) do
    local spell=progress.spells and progress.spells[i];
    if spell then
      local rec=catalog and catalog:Get("spell",spell.key);
      r.icon:SetTexture(iconTexture(rec));
      r.name:SetText(trunc(catalog and catalog:Name("spell",spell.key,lang) or spell.key,19));
      local status,color;
      if spell.status=="UNKNOWN" then status="?";color={0.74,0.77,0.82};
      elseif spell.remindAfter then status=fr and "Bannir" or "Banish";color={1,0.43,0.46};
      elseif spell.status=="ACHIEVED" then status=fr and "OK" or "OK";color={0.42,0.95,0.62};
      elseif spell.rank then status="R"..tostring(spell.rank);color={0.75,0.87,1};
      else status=fr and "Manque" or "Missing";color={0.94,0.67,0.42};end
      r.state:SetText(status);r.state:SetTextColor(unpack(color));r:Show();
    else r:Hide() end
  end
  local known,have=0,0;
  for _,item in ipairs(progress.jewelry or {}) do
    if item.state~="UNKNOWN" then known=known+1 end
    if item.state=="EQUIPPED" or item.state=="ALTERNATIVE" then have=have+1 end
  end
  f.gear:SetText(fr and "BIJOUX CONSEILLÉS" or "RECOMMENDED JEWELS");
  f.gear:SetTextColor(unpack(c.gold));
  f.gearCount:SetText(tostring(have).."/"..tostring(#(progress.jewelry or {})));
  f.gearCount:SetTextColor(unpack(c.mute));
  for i,r in ipairs(f.jewels) do
    local item=progress.jewelry and progress.jewelry[i];
    if item then
      local kind=item.group=="amulets" and "amulet" or "jewel";
      local rec=catalog and catalog:Get(kind,item.key);
      r.icon:SetTexture(iconTexture(rec));
      r.name:SetText(trunc(catalog and catalog:Name(kind,item.key,lang) or item.key,21));
      local status,color;
      if item.state=="EQUIPPED" then status="OK";color={0.42,0.95,0.62};
      elseif item.state=="ALTERNATIVE" then status="ALT";color={0.72,0.84,1};
      elseif item.state=="MISSING" then status=fr and "Manque" or "Missing";color={0.94,0.67,0.42};
      else status="?";color={0.74,0.77,0.82};end
      r.state:SetText(status);r.state:SetTextColor(unpack(color));r:Show();
    else r:Hide() end
  end
  f.info:SetText(known==0 and (fr and "? = équipement non identifié" or "? = equipment not identified") or
    (fr and "Suivi informatif · aucun choix auto" or "Read-only · no automatic choice"));
  f.info:SetTextColor(unpack(c.mute));
  f:Show();
end
function H.UpdateCards(self, build, snapshot, phase, theme)
  if not self.cardRoot and type(CreateFrame)=="function" and UIParent then
    self.cardRoot=CreateFrame("Frame","RBPCardHighlights",UIParent);
    self.cardRoot:SetFrameStrata("FULLSCREEN_DIALOG");self.cardRoot:SetFrameLevel(130);
    self.cardRoot:EnableMouse(false);self.marks={};
    if type(AZS_SetOnTopOfScreens)=="function" then
      -- Optional API: a client mismatch must not break the rest of the HUD.
      pcall(AZS_SetOnTopOfScreens,"RBPCardHighlights",true);
    end
  end
  if not self.cardRoot then return end
  local showing=snapshot and snapshot.cards and
    (snapshot.cards.kind=="spell" or snapshot.cards.kind=="jewel" or snapshot.cards.kind=="amulet") and
    AZSCardsFrame and AZSCardsFrame.IsShown and AZSCardsFrame:IsShown();
  local c=THEMES[theme] or THEMES.standard;
  for i=1,8 do
    local card=_G and _G["AZSCard"..i];
    local hint=showing and card and ns.LiveTracker.CardHint(build,phase,snapshot,snapshot.cards.cards and snapshot.cards.cards[i]);
    local mark=self.marks[i];
    if card and not mark then
      mark=CreateFrame("Frame",nil,card);
      mark:SetFrameLevel(card:GetFrameLevel()+15);mark:EnableMouse(false);
      mark:SetAllPoints(card);
      mark.border={};
      for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local t=mark:CreateTexture(nil,"OVERLAY");t:SetTexture(WHITE);
        if side=="TOP" or side=="BOTTOM" then
          t:SetHeight(3);t:SetPoint(side.."LEFT",mark,side.."LEFT",1,0);
          t:SetPoint(side.."RIGHT",mark,side.."RIGHT",-1,0);
        else
          t:SetWidth(3);t:SetPoint("TOP"..side,mark,"TOP"..side,0,-3);
          t:SetPoint("BOTTOM"..side,mark,"BOTTOM"..side,0,3);
        end
        mark.border[#mark.border+1]=t;
      end
      mark.note=label(mark,"GameFontNormal",12,6,8,150);
      mark:Hide();self.marks[i]=mark;
    end
    if mark then
      if hint then
        local rgb=hint=="wanted" and {0.22,0.97,0.63} or hint=="avoid" and {1,0.27,0.31} or {1,0.57,0.24};
        for _,t in ipairs(mark.border)do t:SetVertexColor(unpack(rgb));end
        mark.note:SetText(hint=="wanted" and "BUILD" or hint=="alternative" and "ALT." or
          hint=="avoid" and (ns.Locale.lang=="frFR" and "ÉVITER" or "AVOID") or
          (ns.Locale.lang=="frFR" and "BANNIR APRÈS" or "BANISH LATER"));
        mark.note:SetTextColor(unpack(rgb));mark:Show();
      else mark:Hide();end
    end
  end
  if showing then self.cardRoot:Show() else self.cardRoot:Hide() end
end
return H;
