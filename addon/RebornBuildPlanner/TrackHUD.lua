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
    return "Interface\\AddOns\\AzerothFieldKitReborn\\media\\ReferenceHUD\\"
  end
  if IsAddOnLoaded("AzerothFieldKit") then
    return "Interface\\AddOns\\AzerothFieldKit\\media\\ReferenceHUD\\"
  end
  return nil
end
local THEMES = {
  standard = { bg={0.025,0.045,0.065,0.96}, edge={0.39,0.55,0.64,1}, gold={0.77,0.87,0.91}, mute={0.65,0.73,0.78},
    art="naxx_card_body_v9.tga" },
  elwynn = { bg={0.035,0.075,0.055,0.96}, edge={0.76,0.56,0.24,1}, gold={1,0.82,0.41}, mute={0.78,0.83,0.70},
    art="elwynn_card_body_v9.tga" },
};
local WIDTH, HEIGHT = 220, 245;
local COMPACT_HEIGHT = 140;
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
-- Uses the authoritative AZSSPELLTIP text; no guessed DPS/bonus values.
local function spellTooltip(owner,tip)
  if not tip or not GameTooltip then return end
  GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");
  GameTooltip:SetText(tip.name or "");
  if tip.rank then
    local rank="Rang "..tostring(tip.rank);
    if tip.targetRank then rank=rank.." / "..tostring(tip.targetRank) end
    if GameTooltip.AddLine then GameTooltip:AddLine(rank,1,.82,.42) end
  end
  if type(tip.native)=="string" and tip.native~="" and GameTooltip.AddLine then
    local raw=string.sub(tip.native,1,2400);
    GameTooltip:AddLine(raw,.87,.93,1,true);
  elseif GameTooltip.AddLine then
    GameTooltip:AddLine("Statistiques non reçues du jeu",.65,.65,.65,true);
  end
  GameTooltip:Show();
end
local function row(parent, y, compact)
  local r=CreateFrame("Frame",nil,parent);
  r:SetSize(WIDTH-12,compact and 14 or 16);
  r:EnableMouse(true);
  r:SetScript("OnEnter",function(self) if self.spellTip then spellTooltip(self,self.spellTip) end end);
  r:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end);
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
  f.titleButton=CreateFrame("Button",nil,f);f.titleButton:SetSize(137,19);
  f.titleButton:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=7,insets={left=2,right=2,top=2,bottom=2}});
  f.titleButton:SetBackdropColor(.055,.13,.085,.95);f.titleButton:SetBackdropBorderColor(.75,.56,.24,1);
  f.titleButton:SetPoint("TOPLEFT",f,"TOPLEFT",12,-7);
  f.title=label(f.titleButton,"GameFontNormal",10,5,3,125);
  f.titleButton:SetScript("OnClick",function()H.ToggleBuildMenu(H)end);
  f.counter=label(f,"GameFontHighlightSmall",9,155,12,28);
  f.counter:SetJustifyH("RIGHT");
  f.themeButton=CreateFrame("Button",nil,f);
  f.themeButton:SetSize(47,16);
  f.themeButton:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=7,insets={left=2,right=2,top=2,bottom=2}});
  f.themeButton:SetBackdropColor(.045,.11,.075,.95);
  f.themeButton:SetBackdropBorderColor(.55,.46,.25,.9);
  f.themeButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-12,-28);
  f.themeButton.text=label(f.themeButton,"GameFontHighlightSmall",9,1,2,45);
  f.themeButton.text:SetJustifyH("RIGHT");
  f.themeButton:SetScript("OnClick",function()if onTheme then onTheme()end end);
  f.themeButton:SetScript("OnEnter",function(self)
    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Changer le thème du suivi");GameTooltip:Show() end
  end);
  f.themeButton:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end);
  f.collapseButton=CreateFrame("Button",nil,f);f.collapseButton:SetSize(23,18);
  f.collapseButton:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=7,insets={left=2,right=2,top=2,bottom=2}});
  f.collapseButton:SetBackdropColor(.12,.17,.09,.98);f.collapseButton:SetBackdropBorderColor(.8,.64,.31,1);
  f.collapseButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-11,-7);
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
  f.stageButton.text=label(f.stageButton,"GameFontHighlightSmall",9,1,1,150);
  f.stageButton:SetScript("OnClick",function()if onStage then onStage()end end);
  f.rule=f:CreateTexture(nil,"ARTWORK");f.rule:SetTexture(WHITE);
  f.rule:SetHeight(1);
  f.rule:SetPoint("TOPLEFT",f,"TOPLEFT",12,-46);
  f.rule:SetPoint("TOPRIGHT",f,"TOPRIGHT",-12,-46);
  f.rows={};
  for i=1,6 do f.rows[i]=row(f,49+(i-1)*16,false) end
  f.gear=label(f,"GameFontNormalSmall",9,12,149,159);
  f.gearCount=label(f,"GameFontHighlightSmall",9,176,149,27);
  f.gearCount:SetJustifyH("RIGHT");
  f.jewels={};
  for i=1,5 do f.jewels[i]=row(f,162+(i-1)*13,true) end
  -- Bottom line reserved as padding: no message below the fifth jewel row.
  f.mini={};
  f.miniSpellLabel=label(f,"GameFontNormalSmall",9,14,48,130);
  f.miniGearLabel=label(f,"GameFontNormalSmall",9,14,91,130);
  f.miniGearCount=label(f,"GameFontHighlightSmall",9,180,91,27);
  for i=1,11 do
    local cell=CreateFrame("Frame",nil,f);
    cell:SetSize(22,22);cell:EnableMouse(true);
    cell:SetScript("OnEnter",function(self)
      if self.spellTip then spellTooltip(self,self.spellTip)
      elseif GameTooltip and self.tip then
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.tip);GameTooltip:Show()
      end
    end);
    cell:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end);
    local row=i<=6 and 0 or 1;
    local col=row==0 and (i-1) or (i-7);
    cell:SetPoint("TOPLEFT",f,"TOPLEFT",14+col*31,-64-row*43);
    cell.bg=cell:CreateTexture(nil,"BACKGROUND");cell.bg:SetAllPoints(cell);
    cell.bg:SetTexture(WHITE);cell.bg:SetVertexColor(.04,.075,.064,.95);
    -- Thin four-sided status outline, never an opaque coloured square.
    cell.edges={};
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
      local edge=cell:CreateTexture(nil,"OVERLAY");edge:SetTexture(WHITE);
      if side=="TOP" or side=="BOTTOM" then
        edge:SetHeight(2);edge:SetPoint(side.."LEFT",cell,side.."LEFT",0,0);
        edge:SetPoint(side.."RIGHT",cell,side.."RIGHT",0,0);
      else
        edge:SetWidth(2);edge:SetPoint("TOP"..side,cell,"TOP"..side,0,0);
        edge:SetPoint("BOTTOM"..side,cell,"BOTTOM"..side,0,0);
      end
      cell.edges[#cell.edges+1]=edge;
    end
    local t=cell:CreateTexture(nil,"ARTWORK");t:SetSize(20,20);
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
function H.Refresh(self,build,progress,catalog,lang,theme,snapshot)
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
  f.collapseButton.text:SetText(compact and "+" or "−");
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
      local native=snapshot and snapshot.spellTipsKnown and snapshot.spellTips and snapshot.spellTips[spell.key];
      r.spellTip={
        name=catalog and catalog:Name("spell",spell.key,lang) or spell.key,
        rank=spell.rank,targetRank=spell.targetRank,native=native
      };
      local status,color;
      if spell.status=="UNKNOWN" then status="?";color={0.74,0.77,0.82};
      elseif spell.remindAfter then status=spell.rank and ("R"..spell.rank.." !") or (fr and "Bannir" or "Banish");color={1,0.43,0.46};
      elseif spell.status=="ACHIEVED" then status=spell.rank and ("R"..spell.rank) or "OK";color={0.42,0.95,0.62};
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
      local name=catalog and catalog:Name(kind,item.key,lang) or item.key;
      local status;
      if i<=6 and item.remindAfter then status=fr and "Bannir après acquisition" or "Banish after acquisition"
      elseif state=="ACHIEVED" or state=="EQUIPPED" then status=fr and "Acquis" or "Owned"
      elseif state=="ALTERNATIVE" then status=fr and "Alternative" or "Alternative"
      elseif state=="UNKNOWN" then status=fr and "État inconnu" or "Unknown"
      else status=fr and "Manquant" or "Missing" end
      m.cell.tip=tostring(name).." - "..status;
      m.cell.spellTip=nil;
      if i<=6 then
        local native=snapshot and snapshot.spellTipsKnown and snapshot.spellTips and snapshot.spellTips[item.key];
        m.cell.spellTip={name=name,rank=item.rank,targetRank=item.targetRank,native=native};
      end
      -- Keep game icons in their original colours: status lives in the rim.
      t:SetVertexColor(1,1,1,1);
      local rgb;
      if i<=6 and item.remindAfter then rgb={.96,.30,.34}
      elseif state=="ACHIEVED" or state=="EQUIPPED" then rgb={.30,.88,.49}
      elseif state=="ALTERNATIVE" then rgb={.45,.72,1}
      elseif state=="UNKNOWN" then rgb={.52,.56,.59}
      else rgb={.94,.66,.28} end
      for _,edge in ipairs(m.cell.edges) do edge:SetVertexColor(unpack(rgb)) end
      m.cell:Show()
    else m.cell:Hide() end
  end
  f:Show();
end
-- Pure presentation: no card click handlers or native card mutations.
local CARD_STYLES={
  wanted={color={0.98,0.79,0.34}, label="BUILD"},
  alternative={color={0.75,0.66,0.46}, label="ALT."},
  avoid={color={0.93,0.37,0.37}, label="AVOID"},
  banish_after={color={1.00,0.56,0.26}, label="BANISH LATER"},
};
local function paint(t,rgb,alpha)
  t:SetVertexColor(rgb[1],rgb[2],rgb[3],alpha or 1);
end
-- Anchor the highlight to the actual card frame perimeter. The earlier
-- 35px top / 37px bottom insets accidentally framed the card's contents.
local function cardEdge(parent,side,thickness,offset,layer)
  local t=parent:CreateTexture(nil,layer or "OVERLAY");
  t:SetTexture(WHITE);
  if side=="TOP" or side=="BOTTOM" then
    t:SetHeight(thickness);
    t:SetPoint(side.."LEFT",parent,side.."LEFT",-offset,0);
    t:SetPoint(side.."RIGHT",parent,side.."RIGHT",offset,0);
  else
    t:SetWidth(thickness);
    t:SetPoint("TOP"..side,parent,"TOP"..side,0,offset);
    t:SetPoint("BOTTOM"..side,parent,"BOTTOM"..side,0,-offset);
  end
  return t;
end
local function createCardMark(card)
  local mark=CreateFrame("Frame",nil,card);
  mark:SetFrameLevel(card:GetFrameLevel()+15);
  mark:SetAllPoints(card);
  mark:EnableMouse(false);
  mark.border={};mark.glow={};mark.corners={};
  -- The edge is aligned with the metallic outer border; ADD glow extends
  -- slightly past it, never inward over the card text or artwork.
  for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
    local edge=cardEdge(mark,side,3,1,"OVERLAY");
    local halo=cardEdge(mark,side,10,4,"ARTWORK");
    if halo.SetBlendMode then halo:SetBlendMode("ADD") end
    mark.border[#mark.border+1]=edge;
    mark.glow[#mark.glow+1]=halo;
  end
  for _,point in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}) do
    local horiz=mark:CreateTexture(nil,"OVERLAY");
    horiz:SetTexture(WHITE);horiz:SetSize(13,3);
    horiz:SetPoint(point,mark,point,0,0);
    local vert=mark:CreateTexture(nil,"OVERLAY");
    vert:SetTexture(WHITE);vert:SetSize(3,13);
    vert:SetPoint(point,mark,point,0,0);
    mark.corners[#mark.corners+1]=horiz;
    mark.corners[#mark.corners+1]=vert;
  end
  -- Badge floats ABOVE the top border so that the number and the native
  -- NOUVEAU/AMÉLIORER heading remain fully readable.
  mark.badge=mark:CreateTexture(nil,"OVERLAY");
  mark.badge:SetTexture(WHITE);
  mark.badge:SetSize(86,17);
  mark.badge:SetPoint("BOTTOMRIGHT",mark,"TOPRIGHT",-11,2);
  mark.note=mark:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
  mark.note:SetSize(82,15);
  mark.note:SetPoint("CENTER",mark.badge,"CENTER",0,0);
  mark.note:SetJustifyH("CENTER");
  mark:Hide();
  return mark;
end
-- Native button frames are only observed. The hint is a mouse-transparent
-- child of the native control, so clicking reroll/skip remains the game's job.
local function actionUsable(button)
  if not button or not button.IsShown or not button:IsShown() or button.off then return false end
  if button.IsEnabled and not button:IsEnabled() then return false end
  return true
end
local function makeActionMark(button)
  local target=button.text or button;
  local f=CreateFrame("Frame",nil,button);
  f:SetFrameLevel(button:GetFrameLevel()+5);
  f:EnableMouse(false);
  f:SetPoint("TOPLEFT",target,"TOPLEFT",-6,5);
  f:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",6,-5);
  f.outline={};f.halo={};
  for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
    local border=f:CreateTexture(nil,"OVERLAY");border:SetTexture(WHITE);
    local glow=f:CreateTexture(nil,"ARTWORK");glow:SetTexture(WHITE);
    if glow.SetBlendMode then glow:SetBlendMode("ADD") end
    if side=="TOP" or side=="BOTTOM" then
      border:SetHeight(2);glow:SetHeight(7);
      border:SetPoint(side.."LEFT",f,side.."LEFT",0,0);
      border:SetPoint(side.."RIGHT",f,side.."RIGHT",0,0);
      glow:SetPoint(side.."LEFT",f,side.."LEFT",0,0);
      glow:SetPoint(side.."RIGHT",f,side.."RIGHT",0,0);
    else
      border:SetWidth(2);glow:SetWidth(7);
      border:SetPoint("TOP"..side,f,"TOP"..side,0,0);
      border:SetPoint("BOTTOM"..side,f,"BOTTOM"..side,0,0);
      glow:SetPoint("TOP"..side,f,"TOP"..side,0,0);
      glow:SetPoint("BOTTOM"..side,f,"BOTTOM"..side,0,0);
    end
    f.outline[#f.outline+1]=border;
    f.halo[#f.halo+1]=glow;
  end
  f:Hide();return f;
end
function H.FallbackAction(self,build,snapshot,phase,catalog,lang,showing)
  local fallback=nil;
  if showing and ns.LiveTracker.OfferHasGoal(build,phase,snapshot,catalog,lang)==false then
    local offer=snapshot.cards;
    local reroll=_G and _G.AZSCardsReroll;
    local free=tonumber(offer.rr) or 0;
    local cost=tonumber(offer.rc);
    local gold=tonumber(snapshot.gold);
    if actionUsable(reroll) and
      (free>0 or (cost and cost>=0 and gold and gold>=cost)) then
      fallback="reroll";
    else
      local skip=_G and _G.AZSCardsSkip;
      if actionUsable(skip) then fallback="skip" end
    end
  end
  self.actions=self.actions or {};
  for _,name in ipairs({"reroll","skip"}) do
    local button=_G and _G[name=="reroll" and "AZSCardsReroll" or "AZSCardsSkip"];
    local old=self.actions[name];
    if old and old.button~=button then old.frame:Hide();self.actions[name]=nil;old=nil end
    if button and not old then
      old={button=button,frame=makeActionMark(button)};
      self.actions[name]=old;
    end
    if old then
      if name==fallback then
        local rgb={0.98,0.79,0.34};
        for _,t in ipairs(old.frame.outline) do paint(t,rgb,0.98) end
        for _,t in ipairs(old.frame.halo) do paint(t,rgb,0.16) end
        old.frame:Show();
      else old.frame:Hide() end
    end
  end
  return fallback
end
function H.UpdateCards(self, build, snapshot, phase, theme, catalog, lang)
  if not self.cardRoot and type(CreateFrame)=="function" and UIParent then
    self.cardRoot=CreateFrame("Frame","RBPCardHighlights",UIParent);
    self.cardRoot:SetFrameStrata("FULLSCREEN_DIALOG");
    self.cardRoot:SetFrameLevel(130);
    self.cardRoot:EnableMouse(false);self.marks={};
    if type(AZS_SetOnTopOfScreens)=="function" then
      pcall(AZS_SetOnTopOfScreens,"RBPCardHighlights",true);
    end
  end
  if not self.cardRoot then return end
  local kinds={spell=true,jewel=true,amulet=true,ring=true,trinket=true};
  local cards=snapshot and snapshot.cards;
  local showing=cards and kinds[cards.kind] and
    AZSCardsFrame and AZSCardsFrame.IsShown and AZSCardsFrame:IsShown();
  for i=1,8 do
    local card=_G and _G["AZSCard"..i];
    local hint=showing and card and ns.LiveTracker.CardHint(
      build,phase,snapshot,cards.cards and cards.cards[i],catalog,lang);
    local mark=self.marks[i];
    if card and not mark then mark=createCardMark(card);self.marks[i]=mark end
    if mark then
      local style=hint and CARD_STYLES[hint];
      if style then
        local rgb=style.color;
        for _,t in ipairs(mark.border) do paint(t,rgb,0.87) end
        for _,t in ipairs(mark.glow) do paint(t,rgb,0.11) end
        for _,t in ipairs(mark.corners) do paint(t,rgb,1) end
        paint(mark.badge,rgb,0.86);
        local fr=ns.Locale and ns.Locale.lang=="frFR";
        local caption=style.label;
        if fr and hint=="avoid" then caption="ÉVITER" end
        if fr and hint=="banish_after" then caption="BANNIR APRÈS" end
        if mark.badge.SetWidth then mark.badge:SetWidth(hint=="banish_after" and 113 or 86) end
        if mark.note.SetWidth then mark.note:SetWidth(hint=="banish_after" and 109 or 82) end
        mark.note:SetText(caption);
        mark.note:SetTextColor(0.09,0.065,0.025,1);
        mark:Show();
      else mark:Hide() end
    end
  end
  if showing then self.cardRoot:Show() else self.cardRoot:Hide() end
  self.FallbackAction(self,build,snapshot,phase,catalog,lang,showing);
end
return H;
