-- Read-only compact in-game build tracker. No polling, no native card interaction.
-- Standard follows FieldKit's Naxxramas family; Elwynn follows FieldKit's
-- forest/gold family. FieldKit is optional: own artwork remains the fallback.
local ADDON, ns = ...;
ns = ns or {};
local H = {};
ns.TrackHUD = H;
local WHITE = "Interface\\Buttons\\WHITE8X8";
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border";
local function fieldkitPath()
  if type(IsAddOnLoaded)~="function" then return nil end
  if IsAddOnLoaded("AzerothFieldKitReborn") then
    return "Interface\\\\AddOns\\\\AzerothFieldKitReborn\\\\media\\\\ReferenceHUD\\\\"
  end
  if IsAddOnLoaded("AzerothFieldKit") then
    return "Interface\\\\AddOns\\\\AzerothFieldKit\\\\media\\\\ReferenceHUD\\\\"
  end
  return nil
end
local THEMES = {
  standard = { bg={0.025,0.045,0.065,0.96}, edge={0.39,0.55,0.64,1}, gold={0.77,0.87,0.91}, mute={0.65,0.73,0.78},
    art="naxx_card_body_v9.tga" },
  elwynn = { bg={0.035,0.075,0.055,0.96}, edge={0.76,0.56,0.24,1}, gold={1,0.82,0.41}, mute={0.78,0.83,0.70},
    art="elwynn_card_body_v9.tga" },
};
local WIDTH, HEIGHT = 204, 236;
local COMPACT_HEIGHT = 128;
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
-- Reuse the approved FieldKit COMPLETE card frame matte, not its plain interior
-- or the generic 12px material. Its source tile is 361x244 in a 512x256 atlas.
-- Nine slices keep the actual decorated corners at their native proportions.
local function rim(frame,theme)
  local assetRoot=fieldkitPath();
  local fk=assetRoot~=nil;
  local c=THEMES[theme] or THEMES.standard;
  if fk then
    frame:SetBackdrop({});
    if not frame.rim then
      frame.rim={};
      local xs={0,12/512,500/512,1};
      local ys={0,12/512,500/512,1};
      for y=1,3 do for x=1,3 do
        local t=frame:CreateTexture(nil,"BORDER");
        t:SetTexCoord(xs[x],xs[x+1],ys[y],ys[y+1]);
        frame.rim[#frame.rim+1]={texture=t,x=x,y=y};
      end end
    end
    local w,h=frame:GetWidth(),frame:GetHeight();
    local cap=12;local xs={0,cap,w-cap};local ys={0,cap,h-cap};
    local asset=assetRoot..theme.."_material_v3.tga";
    for _,p in ipairs(frame.rim) do
      local t=p.texture;
      t:SetTexture(asset);t:SetVertexColor(1,1,1,1);
      if p.x==2 and p.y==2 then
        t:SetTexture(WHITE);t:SetVertexColor(c.bg[1],c.bg[2],c.bg[3],1);
      end
      t:ClearAllPoints();t:SetPoint("TOPLEFT",frame,"TOPLEFT",xs[p.x],-ys[p.y]);
      t:SetSize(p.x==2 and math.max(1,w-2*cap) or cap,p.y==2 and math.max(1,h-2*cap) or cap);
      t:Show();
    end
    if not frame.goldFill then
      frame.goldFill=frame:CreateTexture(nil,"BACKGROUND");
      frame.goldFill:SetTexture(WHITE);
      frame.goldFill:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-12);
      frame.goldFill:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-12,12);
    end
    frame.goldFill:SetVertexColor(c.bg[1],c.bg[2],c.bg[3],1);
    frame.goldFill:Show();
  else
    if frame.rim then for _,p in ipairs(frame.rim) do p.texture:Hide() end end
    if frame.goldFill then frame.goldFill:Hide() end
    frame:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=10,
      insets={left=2,right=2,top=2,bottom=2}});
    frame:SetBackdropColor(unpack(c.bg));frame:SetBackdropBorderColor(unpack(c.edge));
  end
end
local function popupButton(parent,text,x,y,w,h,callback)
  local b=CreateFrame("Button",nil,parent);b:SetSize(w,h);
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);
  b.text=label(b,"GameFontHighlightSmall",10,4,3,w-8);
  b.text:SetText(text);
  b:SetScript("OnClick",function()callback()end);
  return b;
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
function H.New(onTheme,onStage,onSelect,onCollapse)
  if type(CreateFrame)~="function" or not UIParent then return nil end
  local f=CreateFrame("Frame","RBPTrackerHUD",UIParent);
  f:SetSize(WIDTH,HEIGHT);
  f:SetFrameStrata("HIGH");f:SetFrameLevel(75);
  f:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-26,180);
  f:SetClampedToScreen(true);f:SetMovable(true);
  f.art=f:CreateTexture(nil,"BACKGROUND");
  f.art:SetPoint("TOPLEFT",f,"TOPLEFT",11,-11);
  f.art:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-11,11);
  f.art:SetTexture(ns.Theme.Media("ultimate_panel"));f.art:SetAlpha(0.19);
  f:EnableMouse(true);f:RegisterForDrag("LeftButton");
  f:SetScript("OnDragStart",function(self)self:StartMoving()end);
  f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end);
  f.title=label(f,"GameFontNormal",10,16,11,116);
  f.titleButton=CreateFrame("Button",nil,f);f.titleButton:SetSize(125,19);
  f.titleButton:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=7,insets={left=2,right=2,top=2,bottom=2}});
  f.titleButton:SetBackdropColor(.055,.13,.085,.95);f.titleButton:SetBackdropBorderColor(.75,.56,.24,1);
  f.titleButton:SetPoint("TOPLEFT",f,"TOPLEFT",12,-7);
  f.titleButton:SetScript("OnClick",function()H.ToggleBuildMenu(H)end);
  f.counter=label(f,"GameFontHighlightSmall",9,142,12,27);
  f.counter:SetJustifyH("RIGHT");
  f.themeButton=CreateFrame("Button",nil,f);
  f.themeButton:SetSize(26,16);
  f.themeButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-26,-27);
  f.themeButton.text=label(f.themeButton,"GameFontHighlightSmall",9,1,2,27);
  f.themeButton:SetScript("OnClick",function()if onTheme then onTheme()end end);
  f.collapseButton=CreateFrame("Button",nil,f);f.collapseButton:SetSize(23,18);
  f.collapseButton:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=7,insets={left=2,right=2,top=2,bottom=2}});
  f.collapseButton:SetBackdropColor(.12,.17,.09,.98);f.collapseButton:SetBackdropBorderColor(.8,.64,.31,1);
  f.collapseButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-7);
  f.collapseButton:SetScript("OnEnter",function(self)
    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Réduire / Agrandir le suivi");GameTooltip:Show() end
  end);
  f.collapseButton:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end);
  f.titleButton:SetScript("OnEnter",function(self)
    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Choisir le build suivi");GameTooltip:Show() end
  end);
  f.titleButton:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end);
  f.collapseButton.text=label(f.collapseButton,"GameFontNormalSmall",10,3,1,14);
  f.collapseButton:SetScript("OnClick",function()if onCollapse then onCollapse()end end);
  f.stageButton=CreateFrame("Button",nil,f);
  f.stageButton:SetSize(WIDTH-12,15);
  f.stageButton:SetPoint("TOPLEFT",f,"TOPLEFT",12,-29);
  f.stageButton.text=label(f.stageButton,"GameFontHighlightSmall",9,1,1,WIDTH-15);
  f.stageButton:SetScript("OnClick",function()if onStage then onStage()end end);
  f.rule=f:CreateTexture(nil,"ARTWORK");f.rule:SetTexture(WHITE);
  f.rule:SetHeight(1);
  f.rule:SetPoint("TOPLEFT",f,"TOPLEFT",12,-46);
  f.rule:SetPoint("TOPRIGHT",f,"TOPRIGHT",-12,-46);
  f.rows={};
  for i=1,6 do f.rows[i]=row(f,49+(i-1)*16,false) end
  f.gear=label(f,"GameFontNormalSmall",9,10,149,152);
  f.gearCount=label(f,"GameFontHighlightSmall",9,153,149,41);
  f.gearCount:SetJustifyH("RIGHT");
  f.jewels={};
  for i=1,5 do f.jewels[i]=row(f,162+(i-1)*13,true) end
  -- Bottom line reserved as padding: no message below the fifth jewel row.
  f.mini={};
  f.miniSpellLabel=label(f,"GameFontNormalSmall",9,13,44,130);
  f.miniGearLabel=label(f,"GameFontNormalSmall",9,13,84,130);
  f.miniGearCount=label(f,"GameFontHighlightSmall",9,157,84,26);
  for i=1,11 do
    local cell=CreateFrame("Frame",nil,f);
    cell:SetSize(22,22);
    local row=i<=6 and 0 or 1;
    local col=row==0 and (i-1) or (i-7);
    cell:SetPoint("TOPLEFT",f,"TOPLEFT",13+col*29,-57-row*40);
    cell.bg=cell:CreateTexture(nil,"BACKGROUND");cell.bg:SetAllPoints(cell);
    cell.bg:SetTexture(WHITE);cell.bg:SetVertexColor(.04,.075,.064,.95);
    cell.ring=cell:CreateTexture(nil,"ARTWORK");cell.ring:SetTexture(WHITE);
    cell.ring:SetPoint("TOPLEFT",cell,"TOPLEFT",-1,1);
    cell.ring:SetPoint("BOTTOMRIGHT",cell,"BOTTOMRIGHT",1,-1);
    cell.ring:SetVertexColor(.43,.35,.20,1);
    local t=cell:CreateTexture(nil,"OVERLAY");t:SetSize(20,20);
    t:SetPoint("CENTER",cell,"CENTER",0,0);
    cell:Hide();f.mini[i]={icon=t,cell=cell};
  end
  f.menu=CreateFrame("Frame",nil,f);f.menu:SetSize(225,184);
  f.menu:SetFrameStrata("DIALOG");f.menu:SetFrameLevel(f:GetFrameLevel()+30);
  f.menu:SetPoint("TOPLEFT",f,"TOPLEFT",0,-19);
  f.menu:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});
  f.menu:SetBackdropColor(.025,.045,.04,.98);f.menu:SetBackdropBorderColor(.85,.65,.25,1);
  f.menu.page=1;f.menu.options={};f.menu.rows={};
  for i=1,7 do
    local b=popupButton(f.menu,"",7,7+(i-1)*20,209,19,function()
      local option=f.menu.options and f.menu.options[(f.menu.page-1)*7+i];
      if option and onSelect then onSelect(option.id) end
      f.menu:Hide();
    end);
    f.menu.rows[i]=b;
  end
  f.menu.prev=popupButton(f.menu,"<",9,153,35,20,function()f.menu.page=math.max(1,f.menu.page-1);H.DrawMenu(H)end);
  f.menu.next=popupButton(f.menu,">",178,153,35,20,function()
    f.menu.page=math.min(math.max(1,math.ceil(#(f.menu.options or {})/7)),f.menu.page+1);H.DrawMenu(H)
  end);
  f.menu.pageText=label(f.menu,"GameFontHighlightSmall",10,83,157,69);
  f.menu.pageText:SetJustifyH("CENTER");f.menu:Hide();
  f:Hide();H.frame=f;return f;
end
function H.DrawMenu(self)
  local f=self.frame;if not f or not f.menu then return end
  local menu=f.menu;menu.page=tonumber(menu.page) or 1;local opts=menu.options or {};
  local pages=math.max(1,math.ceil(#opts/7));
  if menu.page>pages then menu.page=pages end
  for i,b in ipairs(menu.rows) do
    local option=opts[(menu.page-1)*7+i];
    if option then
      b.text:SetText(trunc(option.name,29)..(option.active and "  *" or ""));
      b.text:SetTextColor(option.active and 1 or .83,option.active and .86 or .85,.53);
      b:Show();
    else b:Hide() end
  end
  menu.pageText:SetText(menu.page.."/"..pages);
end
function H.SetBuildOptions(self,options)
  local f=self.frame;if not f then return end
  f.menu.options=options or {};H.DrawMenu(self);
end
function H.ToggleBuildMenu(self)
  local f=self.frame;if not f then return end
  if f.menu:IsShown() then f.menu:Hide() else f.menu.page=1;H.DrawMenu(self);f.menu:Show() end
end
function H.Refresh(self,build,progress,catalog,lang,theme)
  local f=self.frame;if not f then return end
  if not build or not progress or not progress.inRun then f:Hide();return end
  theme=THEMES[theme] and theme or "standard";
  local c=THEMES[theme];
  local compact=self.compact==true;
  local height=compact and COMPACT_HEIGHT or HEIGHT;
  if f:GetHeight()~=height then f:SetHeight(height) end
  rim(f,theme);
  local assetRoot=fieldkitPath();
  if assetRoot then
    f.art:SetTexture(assetRoot..c.art);
    f.art:SetAlpha(0.65);
  else
    f.art:SetTexture(ns.Theme.Media("ultimate_panel"));
    f.art:SetAlpha(0.22);
  end
  f.rule:SetVertexColor(unpack(c.edge));
  f.title:SetText(trunc(build.name,13).."  ▼");f.title:SetTextColor(unpack(c.gold));
  f.counter:SetText(tostring(progress.achieved or 0).."/"..tostring(progress.total or 0));
  f.counter:SetTextColor(unpack(c.mute));
  f.themeButton.text:SetText(theme=="elwynn" and "ELW" or "STD");
  f.collapseButton.text:SetText(compact and "▣" or "▤");
  f.themeButton.text:SetTextColor(unpack(c.gold));
  local fr=lang=="frFR";
  local stage=progress.stage or 1;
  local phaseName=build.phases and build.phases[stage] and build.phases[stage].label;
  if not phaseName or phaseName=="" then
    phaseName=ns.Locale.T(ns.BuildModel.DEFAULT_LABELS[stage] or "Stage");
  end
  f.stageButton.text:SetText((fr and "Étape " or "Stage ")..stage.."/4 · "..trunc(phaseName,22).." >");
  if compact then f.stageButton:Hide();f.rule:Hide();f.gear:Hide();f.gearCount:Hide()
  else f.stageButton:Show();f.rule:Show();f.gear:Show();f.gearCount:Show() end
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
    if compact then r:Hide() end
  end
  local known,have=0,0;
  for _,item in ipairs(progress.jewelry or {}) do
    if item.state~="UNKNOWN" then known=known+1 end
    if item.state=="EQUIPPED" or item.state=="ALTERNATIVE" then have=have+1 end
  end
  f.miniSpellLabel:SetText(fr and "SORTS" or "SPELLS");
  f.miniGearLabel:SetText(fr and "BIJOUX" or "JEWELRY");
  f.miniGearCount:SetText(tostring(have).."/"..tostring(#(progress.jewelry or {})));
  for _,l in ipairs({f.miniSpellLabel,f.miniGearLabel,f.miniGearCount}) do
    l:SetTextColor(unpack(c.gold));if compact then l:Show() else l:Hide() end
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
    if compact then r:Hide() end
  end
  for i,m in ipairs(f.mini) do
    local t=m.icon;
    local item=i<=6 and progress.spells and progress.spells[i] or progress.jewelry and progress.jewelry[i-6];
    if item and compact then
      local kind=i<=6 and "spell" or item.group=="amulets" and "amulet" or "jewel";
      t:SetTexture(iconTexture(catalog and catalog:Get(kind,item.key)));
      local state=i<=6 and item.status or item.state;
      -- Keep game icons in their original colours: status lives in the rim.
      t:SetVertexColor(1,1,1,1);
      if i<=6 and item.remindAfter then m.cell.ring:SetVertexColor(.96,.30,.34,1)
      elseif state=="ACHIEVED" or state=="EQUIPPED" then m.cell.ring:SetVertexColor(.30,.88,.49,1)
      elseif state=="ALTERNATIVE" then m.cell.ring:SetVertexColor(.45,.72,1,1)
      elseif state=="UNKNOWN" then m.cell.ring:SetVertexColor(.52,.56,.59,1)
      else m.cell.ring:SetVertexColor(.94,.66,.28,1) end
      m.cell:Show()
    else m.cell:Hide() end
  end
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
