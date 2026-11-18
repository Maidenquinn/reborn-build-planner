-- TrackHUD: compact optional in-game companion, independent from the planner window.
-- Two schemes: Standard (blue) and Elwynn (wood/forest). No third-party assets
-- are copied; when FieldKit is installed its existing Elwynn artwork can be reused.
-- All card marks are mouse-transparent. Never edits Reborn's buttons or cards.
local ADDON, ns = ...;
ns = ns or {};
local H = {};
ns.TrackHUD = H;
local WHITE = "Interface\\Buttons\\WHITE8X8";
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border";
local THEMES = {
  standard = { bg={0.035,0.075,0.15,0.94}, edge={0.28,0.55,0.82,1}, gold={0.65,0.84,1}, mute={0.72,0.82,0.91} },
  elwynn = { bg={0.065,0.10,0.070,0.94}, edge={0.73,0.59,0.30,1}, gold={1.0,0.85,0.49}, mute={0.83,0.88,0.70} },
};
local function label(parent, name, size, x, y, width)
  local f=parent:CreateFontString(nil,"OVERLAY",name or "GameFontHighlightSmall");
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);f:SetWidth(width);
  f:SetHeight(size+3);f:SetJustifyH("LEFT");return f;
end
local function surface(frame, theme)
  frame:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=12,
    insets={left=3,right=3,top=3,bottom=3}});
  local c=THEMES[theme] or THEMES.standard;
  frame:SetBackdropColor(unpack(c.bg));
  frame:SetBackdropBorderColor(unpack(c.edge));
end
local function trunc(s,n)
  s=tostring(s or "");
  if #s<=n then return s end
  return string.sub(s,1,n-3).."...";
end
function H.New(onTheme)
  if type(CreateFrame)~="function" or not UIParent then return nil end
  local f=CreateFrame("Frame","RBPTrackerHUD",UIParent);
  f:SetWidth(270);f:SetHeight(246);
  f:SetFrameStrata("HIGH");f:SetFrameLevel(75);
  f:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-26,180);
  f:SetClampedToScreen(true);f:SetMovable(true);
  -- The Elwynn visual reuses FieldKit's installed panel artwork if available;
  -- no FieldKit texture is copied into this addon and it remains optional.
  f.art=f:CreateTexture(nil,"BACKGROUND");
  f.art:SetPoint("TOPLEFT",f,"TOPLEFT",3,-3);
  f.art:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-3,3);
  f.art:SetTexture(ns.Theme.Media("ultimate_panel"));
  f.art:SetAlpha(0.19);
  f:EnableMouse(true);f:RegisterForDrag("LeftButton");
  f:SetScript("OnDragStart",function(self)self:StartMoving()end);
  f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end);
  f.title=label(f,"GameFontNormal",14,12,11,185);
  f.counter=label(f,"GameFontHighlightSmall",10,191,14,63);
  f.counter:SetJustifyH("RIGHT");
  f.rule=f:CreateTexture(nil,"ARTWORK");f.rule:SetTexture(WHITE);
  f.rule:SetHeight(1);f.rule:SetPoint("TOPLEFT",f,"TOPLEFT",10,-31);
  f.rule:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-31);
  f.rows={};
  for i=1,6 do
    local row=CreateFrame("Frame",nil,f);row:SetWidth(250);row:SetHeight(25);
    row:SetPoint("TOPLEFT",f,"TOPLEFT",10,-38-(i-1)*27);
    row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(20,20);
    row.icon:SetPoint("LEFT",row,"LEFT",1,0);
    row.name=label(row,"GameFontHighlightSmall",11,26,5,144);
    row.state=label(row,"GameFontNormalSmall",10,175,5,74);row.state:SetJustifyH("RIGHT");
    f.rows[i]=row;
  end
  f.gear=label(f,"GameFontHighlightSmall",11,12,207,242);
  f.info=label(f,"GameFontHighlightSmall",10,12,226,240);
  f.themeButton=CreateFrame("Button",nil,f);f.themeButton:SetSize(48,21);
  f.themeButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4);
  f.themeButton.text=label(f.themeButton,"GameFontHighlightSmall",10,3,5,43);
  f.themeButton:SetScript("OnClick",function()if onTheme then onTheme()end end);
  f:Hide();
  H.frame=f;return f
end
function H.Refresh(self, build, progress, catalog, lang, theme)
  local f=self.frame;if not f then return end;
  if not build or not progress or not progress.inRun then f:Hide();return end
  theme=THEMES[theme] and theme or "standard";
  local c=THEMES[theme];surface(f,theme);
  if theme=="elwynn" and type(IsAddOnLoaded)=="function" and IsAddOnLoaded("AzerothFieldKit") then
    f.art:SetTexture("Interface\\AddOns\\AzerothFieldKit\\media\\ReferenceHUD\\elwynn_card_body_v9.tga");
    f.art:SetAlpha(0.34);
  else
    f.art:SetTexture(ns.Theme.Media("ultimate_panel"));
    f.art:SetAlpha(theme=="elwynn" and 0.23 or 0.16);
  end
  f.rule:SetVertexColor(unpack(c.edge));
  f.title:SetText(trunc(build.name,24));f.title:SetTextColor(unpack(c.gold));
  f.counter:SetText(tostring(progress.achieved).."/"..tostring(progress.total));
  f.counter:SetTextColor(unpack(c.mute));
  f.themeButton.text:SetText(theme=="elwynn" and "ELW" or "STD");
  f.themeButton.text:SetTextColor(unpack(c.gold));
  local fr=lang=="frFR";
  for i,row in ipairs(f.rows) do
    local spell=progress.spells[i];
    if spell then
      local record=catalog and catalog:Get("spell",spell.key);
      row.icon:SetTexture(record and ("Interface\\Icons\\"..tostring(record.icon)) or "Interface\\Icons\\INV_Misc_QuestionMark");
      local name=catalog and catalog:Name("spell",spell.key,lang) or spell.key;
      row.name:SetText(trunc(name,24));row:Show();
      local text,color;
      if spell.status=="UNKNOWN" then text=fr and "?" or "?";color={0.7,0.74,0.8};
      elseif spell.remindAfter then text=fr and "Bannir" or "Banish";color={1,0.48,0.50};
      elseif spell.status=="ACHIEVED" then text=fr and "Acquis" or "Owned";color={0.42,0.95,0.62};
      elseif spell.rank then text="R"..tostring(spell.rank);color={0.75,0.87,1};
      else text=fr and "Manque" or "Missing";color={0.9,0.65,0.45};end
      row.state:SetText(text);row.state:SetTextColor(unpack(color));
    else row:Hide();end
  end
  local known=0;local have=0;
  for _,item in ipairs(progress.jewelry)do
    if item.state~="UNKNOWN" then known=known+1 end
    if item.state=="EQUIPPED" or item.state=="ALTERNATIVE" then have=have+1 end
  end
  f.gear:SetText(fr and "Équipement" or "Equipment");
  f.gear:SetTextColor(unpack(c.gold));
  f.info:SetText(known==0 and (fr and "Statut des bijoux non disponible" or "Jewelry status unavailable") or
    (tostring(have).."/"..tostring(known)..(fr and " emplacements identifiés" or " identified slots")));
  f.info:SetTextColor(unpack(c.mute));
  f:Show();
end
function H.UpdateCards(self, build, snapshot, phase, theme)
  if not self.cardRoot and type(CreateFrame)=="function" and UIParent then
    self.cardRoot=CreateFrame("Frame","RBPCardHighlights",UIParent);
    self.cardRoot:SetFrameStrata("FULLSCREEN_DIALOG");self.cardRoot:SetFrameLevel(130);
    self.cardRoot:EnableMouse(false);self.marks={};
    if type(AZS_SetOnTopOfScreens)=="function" then
      AZS_SetOnTopOfScreens("RBPCardHighlights",true);
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
