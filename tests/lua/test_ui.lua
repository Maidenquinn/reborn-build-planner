-- Lot 3: the REAL Controller/UI/Commands/Core code driven through a headless 3.3.5a widget mock (wowstub.lua).
-- Proves behaviour and a layout lint on estimated text metrics. It does NOT prove rendering in the Reborn client.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");
	local U;

	-- boots a fresh "client": stub world + addon files + ADDON_LOADED (optionally with a saved database)
	local function boot(o)
		o = o or {};
		local world = Stub.new({ width = o.width or 1365, height = o.height or 768, locale = o.locale or "enUS", classToken = o.classToken, className = o.className, noWordWrap = o.noWordWrap });
		for k, v in pairs(o.preset or {}) do world.G[k] = v; end
		local ns, sb = H.loadAddon({ globals = world.G, time = world.G.time });
		U = ns.Util;
		local env = { world = world, ns = ns, sb = sb, G = world.G };
		function env.start() world.fire("ADDON_LOADED", "RebornBuildPlanner"); env.c, env.ui = ns.controller, ns.ui; return env; end
		function env.open() world.G.SlashCmdList.REBORNPLANNER(""); env.root = world.G.RebornBuildPlannerFrame; return env.root; end
		function env.h() return ns.storage; end
		function env.texts() return table.concat(world.texts(), " | "); end
		function env.lint() return world.lint(env.root); end
		if not o.noStart then env.start(); end
		return env;
	end
	-- simulates /reload: the saved variables are what the client would write, re-read into a brand new world
	local function reload(env, o)
		o = o or {};
		local text = H.serialize("RebornBuildPlannerDB", env.G.RebornBuildPlannerDB);
		o.preset = { RebornBuildPlannerDB = H.reload("RebornBuildPlannerDB", text) };
		return boot(o);
	end
	local function modalButton(env, label) return env.world.clickLabel(label, env.G.RebornBuildPlannerModal); end
	local function createViaUI(env, name, classKeyClicks)
		env.world.clickLabel(env.ns.Locale.T("Create a build"), env.ui.views.library);
		local m = env.G.RebornBuildPlannerModal;
		ok(m:IsShown(), "create dialog shown");
		env.world.type(env.G.RebornBuildPlannerModalEdit, name);
		for _ = 1, classKeyClicks or 0 do env.world.click(env.ui.modal.cycle.next); end
		modalButton(env, env.ns.Locale.T("Create"));
		return env.c.state.selectedId;
	end
	local function T(env, s) return env.ns.Locale.T(s); end

	test("Beta minimap: native drag, compact icon, saved position and scaled map", function()
		local world = Stub.new({ width = 1365, height = 768 });
		world.G.Minimap = world.G.CreateFrame("Frame", "Minimap", world.G.UIParent);
		world.G.Minimap:SetSize(140, 140);
		world.G.Minimap:SetScale(0.8);
		world.G.Minimap:SetPoint("TOPRIGHT", world.G.UIParent, "TOPRIGHT", -18, -18);
		local ns = H.loadAddon({globals = world.G, time = world.G.time});
		world.fire("ADDON_LOADED", "RebornBuildPlanner");
		local icon = world.G.RBPMinimapButton;
		ok(icon ~= nil and icon:IsShown(), "minimap icon appears immediately");
		eq(icon:GetWidth(), 30, "compact button size");
		ok(icon.drag, "native left-button dragging registered");
		ok(icon.emblem and icon.emblem.texture and icon.emblem.texture:find("ultimate_minimap",1,true),
			"uses packaged original compass rather than a missing game icon");
		eq(icon.roundRing,nil,"no second tracking border over the custom seal");
		eq(icon.scripts.OnMouseWheel,nil,"wheel rotation fallback removed");
		eq(icon.scripts.OnUpdate,nil,"no idle per-frame work");

		local mx,my=world.G.Minimap:GetCenter();
		local scale=world.G.Minimap:GetEffectiveScale();
		local cursorX,cursorY=mx*scale,my*scale;
		world.G.GetCursorPosition=function() return cursorX,cursorY end;
		icon.scripts.OnDragStart(icon);
		ok(icon.scripts.OnUpdate~=nil,"drag updates only while held");
		cursorX,cursorY=(mx-75)*scale,(my+18)*scale;
		icon.scripts.OnUpdate(icon,0.01);
		icon.scripts.OnDragStop(icon);
		local pos=ns.storage:GetSetting("minimapPosition");
		ok(pos and pos.x < -75 and pos.y > 15, "scaled drag persists correct map-relative position: " .. H.fmt(pos));
		eq(icon.scripts.OnUpdate,nil,"drag frame update removed at drag stop");
		icon.scripts.OnClick(icon,"LeftButton");
		no(ns.ui:IsShown(),"drag release does not toggle planner");
		local x1=icon:GetPoint();
		eq(x1,"CENTER");
		world.click(icon);
		ok(ns.ui:IsShown(),"normal left-click opens planner without active build");
		world.click(icon);
		no(ns.ui:IsShown(),"second click closes planner");
	end);

	test("Beta hotfix: idle HUD remains usable without a followed build", function()
		local events={};
		local e=boot({preset={
			AZS={On=function(event,fn) events[event]=fn end},
			AZS_RUN={ph="playing"}, AZS_ZONE={hub=0,run="run-idle"}
		}});
		ok(e.ns.Runtime.ready);
		local hud=e.ns.TrackHUD.frame;
		ok(hud:IsShown(),"idle HUD is visible without any active build");
		ok(hud.title:GetText():find("Choose a build",1,true),"idle HUD invites build selection");
		ok(hud.openButton:IsShown(),"idle HUD retains the planner launch control");
		e.world.click(hud.openButton);
		ok(e.ns.ui:IsShown(),"idle HUD opens the planner");
		ok(e.h():SetSetting("trackerEnabled",false));
		e.ns.Runtime.Refresh();
		no(hud:IsShown(),"explicitly disabled tracker stays hidden");
		ok(e.h():SetSetting("trackerEnabled",true));
		e.ns.Runtime.Refresh();
		ok(hud:IsShown(),"re-enabled HUD returns without a build");
	end);

  test("perf: card packets refresh only overlays, gear packets update full HUD",function()
    local events={}
    local e=boot({preset={
      AZS={On=function(event,fn) events[event]=fn end},
      AZS_RUN={ph="playing"},AZS_ZONE={hub=0,run="perf-1"},
      AZS_SPELLS={{key="whirlwind",rank=1}},AZS_GEAR={},
      AZS_CARDS={kind="spell",cards={{key="whirlwind"}}}
    }})
    local hud=e.ns.TrackHUD
    local full,overlays=0,0
    local originalRefresh=hud.Refresh
    local originalCards=hud.UpdateCards
    hud.Refresh=function(...) full=full+1;return originalRefresh(...) end
    hud.UpdateCards=function(...) overlays=overlays+1;return originalCards(...) end
    for _=1,80 do events.AZSCARDS();events.AZSCARDTIP() end
    eq(full,0,"160 card packets must not rebuild the tracker")
    eq(overlays,160,"every card packet must still refresh highlights")
    events.AZSGEAR()
    eq(full,1,"equipment changes still refresh tracker")
    hud.Refresh=originalRefresh;hud.UpdateCards=originalCards
  end);

	-- ------------------------------------------------------------------ 3A: native initialisation
	test("3A: nothing is created or read before ADDON_LOADED; the event of another addon is ignored", function()
		local e = boot({ noStart = true });
		eq(e.G.RebornBuildPlannerDB, nil);
		eq(e.G.SlashCmdList.REBORNPLANNER, nil);
		eq(e.G.RebornBuildPlannerFrame, nil);
		e.world.fire("ADDON_LOADED", "SomeOtherAddon");
		eq(e.G.RebornBuildPlannerDB, nil);
		e.world.fire("ADDON_LOADED", "RebornBuildPlanner");
		eq(e.G.RebornBuildPlannerDB.schema, 1);
		eq(e.G.SLASH_REBORNPLANNER1, "/rbp");
		eq(e.G.SLASH_REBORNPLANNER2, "/rebornplanner");
		ok(e.G.SlashCmdList.REBORNPLANNER ~= nil);
		eq(e.G.RebornBuildPlannerFrame, nil, "no window until the first /rbp");
		e.world.fire("ADDON_LOADED", "RebornBuildPlanner");   -- unregistered: a second event does nothing
		local f = nil;
		for _, fr in ipairs(e.world.all) do if fr.registered and next(fr.registered) == nil and fr.scripts.OnEvent then f = fr; end end
		ok(f ~= nil, "the loader frame unregistered ADDON_LOADED");
	end);

	test("Lot4: real event subscriptions drive compact HUD and native card overlay without actions", function()
		local events={};
		local e=boot({preset={
			AZS={On=function(event,fn) events[event]=fn end},
			AZS_RUN={ph="playing"}, AZS_ZONE={hub=0,run="run-a"},
			AZS_SPELLS={{key="whirlwind",rank=1}}, AZS_GEAR={},
			AZS_CARDS={kind="spell",cards={{key="whirlwind"},{key="execute"},{key="rend"}}}
		}});
		ok(e.ns.Runtime.ready,"live API available");
		ok(type(events.AZSSPELLS)=="function" and type(events.AZSCARDS)=="function");
		local h=e.h();local id=assert(h:Create({name="Warrior plan",class="warrior"}));
		local b=assert(e.ns.BuildModel.AddSpell(h:Get(id),1,"whirlwind",nil,e.ns.catalog));
		b=assert(e.ns.BuildModel.AddSpell(b,1,"execute",nil,e.ns.catalog));
		b=assert(e.ns.BuildModel.SetBanishAfter(b,1,"execute",true,e.ns.catalog));
		ok(h:Update(id,b));ok(e.c:Activate(id));
		events.AZSSPELLS();
		eq(e.ns.Runtime.progress.achieved,1);
		ok(e.ns.Runtime.hud:IsShown(),"compact tracker visible in a real run");
		ok(h:SetSetting("trackerOpacity",0));
		events.AZSSPELLS();
		local tracker=e.ns.TrackHUD.frame;
		eq(tracker.backdropColor[4],0,"only native tracker background is transparent");
		eq(tracker.art.alpha,0,"tracker background art fades to zero");
		ok(tracker.alpha==nil or tracker.alpha==1,"whole tracker stays fully opaque");
		ok(tracker.title.alpha==nil or tracker.title.alpha==1,"labels stay legible");
		ok(h:SetSetting("trackerOpacity",1));events.AZSSPELLS();
		eq(tracker.backdropColor[4],1,"HUD background becomes solid again");

		ok(e.ns.TrackHUD.frame.openButton,"HUD has a dedicated planner button");
		e.world.click(e.ns.TrackHUD.frame.openButton);
		ok(e.ns.ui:IsShown(),"planner opens directly from the live HUD");

		eq(e.ns.TrackHUD.frame.rows[1].state.text,"R1","acquired spell shows its actual rank");
		e.G.AZS_SPELLTIPS={whirlwind="Hits the nearest enemy for 175 arcane damage."};
		events.AZSSPELLTIP();
		eq(e.ns.TrackHUD.frame.rows[1].spellTip.native,
		"Hits the nearest enemy for 175 arcane damage.","tooltip uses authoritative AZSSPELLTIP");
		ok(e.ns.TrackHUD.frame.rows[1].spellTip.rank==1);

		local cardRoot=e.G.CreateFrame("Frame","AZSCardsFrame",e.G.UIParent);
		cardRoot:Show();
		for i=1,3 do e.G.CreateFrame("Frame","AZSCard"..i,cardRoot); end
		events.AZSCARDS();
		ok(e.ns.TrackHUD.marks[1] and e.ns.TrackHUD.marks[1]:IsShown(),"wanted card outlined");
		ok(e.ns.TrackHUD.marks[2] and e.ns.TrackHUD.marks[2]:IsShown(),"unowned banish-after remains wanted");
		ok(e.ns.TrackHUD.marks[1].mouse==false,"overlay cannot capture card clicks");
		local goldMark=e.ns.TrackHUD.marks[1];
		eq(#goldMark.rim,8,"ornate card border has four corners and four edges");
		eq(#goldMark.halo,8,"soft halo uses same eight decorative slices");
		ok(goldMark.shineEnabled,"recommended build card activates shape-matched breathing glow");
		ok(goldMark.rim[1].texture:find("elwynn_material_v3",1,true)~=nil or
		   goldMark.rim[1].texture:find("window_nine",1,true)~=nil,
		   "render uses decorative material, never WHITE8X8 fill strips");
		ok(goldMark.halo[1].coords~=nil,"glow segments use corner-preserving atlas UVs");
		ok(goldMark.rim[1].coords~=nil,"frame corners sample decorative material");
		eq(#goldMark.ember,8,"second ornate ADD rim highlights the engraving at pulse peak");
		eq(goldMark.shineStrength,1,"BUILD is allowed a clearly visible external halo");
		ok(goldMark.haloFrame.points and #goldMark.haloFrame.points>=2,
		  "halo frame extends beyond decorative rim");
		ok(type(goldMark.scripts.OnUpdate)=="function","visible card owns its animation");
		goldMark.scripts.OnUpdate(goldMark,0);
		local low=goldMark.halo[1].alpha;
		goldMark.scripts.OnUpdate(goldMark,1/120);
		eq(goldMark.halo[1].alpha,low,"tiny frame delta does not force texture alpha updates");
		goldMark.scripts.OnUpdate(goldMark,1);
		local high=goldMark.halo[1].alpha;
		ok(high>low+.25,"halo opacity changes visibly throughout the pulse");
		eq(goldMark.rim[1].vertex[4],.95,"static ornate frame remains steady");
		ok(goldMark.mouse==false,"gold rim cannot block native card clicks");

		local reroll=e.G.CreateFrame("Button","AZSCardsReroll",cardRoot);
		local skip=e.G.CreateFrame("Button","AZSCardsSkip",cardRoot);
		reroll:Show();skip:Show();
		e.G.AZS_RUN.gold=300;
		e.G.AZS_CARDS={kind="spell",cards={{key="rend"}},rr=0,rc=30};
		events.AZSCARDS();
		eq(e.ns.TrackHUD.actions.reroll.frame:IsShown(),true,"reroll gold frame when no build cards");
		eq(e.ns.TrackHUD.actions.skip.frame:IsShown(),false,"skip not highlighted while reroll available");
		e.G.AZS_RUN.gold=0;events.AZSRUN();
		eq(e.ns.TrackHUD.actions.reroll.frame:IsShown(),false);
		eq(e.ns.TrackHUD.actions.skip.frame:IsShown(),true,"skip highlighted when reroll unaffordable");
		-- Even free rerolls are not suggested when the native control is off.
		reroll.off=true;e.G.AZS_CARDS.rr=3;events.AZSCARDS();
		eq(e.ns.TrackHUD.actions.reroll.frame:IsShown(),false,"disabled reroll is ignored");
		eq(e.ns.TrackHUD.actions.skip.frame:IsShown(),true);
		reroll.off=nil;
		-- Jewelry offers use the same fallback rules as spell offers.
		local firstJewel=e.ns.catalog.data.jewelry[1].key;
		e.G.AZS_CARDS={kind="jewel",cards={{key=firstJewel}},rr=1,rc=200};
		events.AZSCARDS();
		eq(e.ns.TrackHUD.actions.reroll.frame:IsShown(),true,"unwanted jewelry offers highlight reroll");
		eq(e.ns.TrackHUD.actions.skip.frame:IsShown(),false);

		e.G.AZS_CARDS={kind="spell",cards={{key="whirlwind"}},rr=2,rc=0};
		events.AZSCARDS();
		eq(e.ns.TrackHUD.actions.reroll.frame:IsShown(),false,"no fallback while wanted card offered");
		eq(e.ns.TrackHUD.actions.skip.frame:IsShown(),false);
		e.G.AZS_CARDS={kind="spell",cards={{key="totally_unknown_spell"}},rr=2,rc=0};
		events.AZSCARDS();
		eq(e.ns.TrackHUD.actions.reroll.frame:IsShown(),false,"unknown cards do not trigger false fallback");
		e.G.AZS_CARDS={kind="spell",cards={{key="whirlwind"},{key="execute"},{key="rend"}}};
		events.AZSCARDS();

		-- Ban confirmation is observational only: do not mark a spell until
		-- the native offer acknowledges one consumed banishment.
		e.G.AZS_CARDS={kind="spell",bn=3,cards={{key="execute"}}};
		e.G.AZS_ZONE.run="run-a";
		e.ns.Runtime.ObserveBanishCommand("AZSCMD","banish 1");
		eq(e.ns.Runtime.bans.execute,nil,"ban not yet acknowledged");
		e.G.AZS_CARDS.bn=2;events.AZSCARDS();
		eq(e.ns.Runtime.bans.execute,true,"native decrement confirms ban");
		eq(#e.ns.Runtime.progress.banishedSpells,1);
		e.G.AZS_ZONE.run="run-b";events.AZSZONE();
		eq(e.ns.Runtime.bans.execute,nil,"next run clears previous bans");
		e.G.AZS_ZONE.run="run-a";events.AZSZONE();
		e.G.AZS_CARDS={kind="spell",cards={{key="whirlwind"},{key="execute"},{key="rend"}}};events.AZSCARDS();
		-- In-game build selection must use the same validated active pointer as the planner.
		local second=assert(h:Create({name="Second warrior plan",class="warrior"}));
		ok(e.ns.Runtime.SelectBuild(second));
		eq(h:GetActive("warrior"),second);
		eq(e.ns.Runtime.Active().name,"Second warrior plan");
		ok(e.ns.Runtime.SelectBuild(id));
		eq(h:GetActive("warrior"),id);
		local menu=e.ns.TrackHUD.frame.menu;
		ok(menu and menu.options and #menu.options==2,"tracked build selector populated");
		eq(e.ns.Runtime.ToggleCompact(),true);
		eq(h:GetSetting("trackerCompact"),true);
		-- Returning to an already observed server run now restores its confirmed ban
		-- from SavedVariables, so the HUD includes its extra banishment row.
		eq(e.ns.TrackHUD.frame:GetHeight(),211);
		eq(e.ns.Runtime.ToggleCompact(),false);
		eq(e.ns.TrackHUD.frame:GetHeight(),316);
		eq(e.ns.Runtime.ToggleTheme(),"elwynn");
		eq(h:GetSetting("trackerTheme"),"elwynn");
		eq(e.ns.Runtime.CycleStage(),2,"HUD moves to next manually selected phase");
		eq(e.ns.Runtime.progress.stage,2);
		for _=1,3 do e.ns.Runtime.CycleStage(); end
		eq(e.ns.Runtime.progress.stage,1,"cycles 4 stages without gameplay assumptions");
		eq(e.ns.Runtime.ToggleHud(),false);
		no(e.ns.Runtime.hud:IsShown(),"HUD can be disabled separately");
		ok(e.ns.TrackHUD.marks[1]:IsShown(),"card marks remain informational when HUD hidden");
		e.G.AZS_ZONE.hub=1;events.AZSZONE();
		no(e.ns.Runtime.hud:IsShown(),"no phantom tracker in hub");
		no(e.ns.TrackHUD.marks[1]:IsShown(),"stale proposed cards cleared in hub");
		eq(h:Get(id).name,"Warrior plan","tracking does not edit build data");
	end);

	test("3A: only the planned globals are written; nothing foreign is read", function()
		local e = boot();
		e.open();
		local allowed = { RebornBuildPlanner = true, RebornBuildPlannerDB = true, SLASH_REBORNPLANNER1 = true, SLASH_REBORNPLANNER2 = true, SlashCmdList = true };
		for k in pairs(e.sb.writes) do
			ok(allowed[k] or string.find(k, "^RebornBuildPlanner"), "unexpected global write: " .. k);
		end
		local reads = {};
		for k in pairs(e.sb.reads) do reads[#reads + 1] = k; end
		for i = #reads, 1, -1 do if reads[i] == "RebornBuildPlannerDB" or reads[i] == "GetAddOnMetadata" or reads[i] == "AZS" or reads[i] == "Minimap" then table.remove(reads, i); end end
		eq(reads, {}, "non-client globals read");
	end);

	test("3A: fifteen-language dropdown, automatic client language and fallback persist", function()
		local e = boot({ locale = "frFR" }); e.open();
		eq(e.ns.Locale.lang, "frFR");
		eq(e.ns.Locale.Selection(), "auto");
		eq(#e.ns.Locale.LANGUAGES, 15);
		ok(e.ui.languageButton:GetText():find("Automatic", 1, true));
		e.world.click(e.ui.languageButton);
		ok(e.ui.languageMenu:IsShown() and #e.ui.languageMenu.buttons == 15);
		ok(e.ui.languageDismiss:IsShown(), "outside-click catcher is active when menu opens");
		ok(e.ui.languageDismiss:GetFrameLevel() < e.ui.languageMenu:GetFrameLevel(), "menu above click-away catcher");
		local en = e.ui.languageMenu.buttons[2];
		e.world.click(en);
		eq(e.ns.Locale.lang, "enUS");
		eq(e.ns.Locale.Selection(), "enUS");
		eq(e.h():GetSetting("lang"), "enUS");
		no(e.ui.languageMenu:IsShown(), "menu closes after selection");
		no(e.ui.languageDismiss:IsShown(), "click-away catcher removed after selection");
		e.world.click(e.ui.languageButton);
		e.world.click(e.ui.languageMenu.buttons[5]); -- German, not yet translated
		eq(e.ns.Locale.lang, "deDE");
		eq(e.ns.Locale.T("Search:"), "Suchen:", "German navigation uses its starter dictionary");
		eq(e.ns.Locale.T("Wanted spells, in priority order (%d/%d)"), "Wanted spells, in priority order (%d/%d)", "untranslated German keys fall back to English");
		local nextWorld = reload(e, { locale = "frFR" });
		eq(nextWorld.ns.Locale.lang, "deDE", "explicit locale remains selected");
		nextWorld.open();
		nextWorld.world.click(nextWorld.ui.languageButton);
		nextWorld.world.click(nextWorld.ui.languageMenu.buttons[1]); -- Automatic
		eq(nextWorld.ns.Locale.Selection(), "auto");
		eq(nextWorld.ns.Locale.lang, "frFR");
		eq(nextWorld.h():GetSetting("lang"), "auto");
	end);

	test("3A: unsaved changes modal has explicit visible footer with 3 actions above main window", function()
		local e = boot({ locale = "frFR" }); e.open();
		e.ui:ShowModal({ title = "Modifications non enregistrées",
			body = "Ce build a été modifié.", buttons = { "Enregistrer", "Ignorer", "Continuer" },
			cancelIndex = 3, onChoose = function() end });
		local m = e.ui.modal;
		ok(m:IsShown() and m.footer and m.footer:IsShown());
		ok(m.dim and m.dim:IsShown(), "modal draws a focus scrim");
		ok(m.dim:GetFrameLevel() < m:GetFrameLevel(), "scrim below dialog");
		ok(m.footer:GetFrameLevel() > e.root:GetFrameLevel(), "footer above planner");
		for i = 1, 3 do
			ok(m.b[i]:IsShown(), "action " .. i .. " visible");
			ok(m.b[i]:GetFrameLevel() > m.footer:GetFrameLevel(), "action above footer");
			ok(#m.b[i]:GetText() > 0, "action has a label");
		end
		e.ui:ModalCancel();
		no(m:IsShown());
		no(m.dim:IsShown(), "focus scrim cleared after cancel");
	end);

	test("3A: command collisions are left alone", function()
		local e = boot({ noStart = true, preset = { SLASH_OTHER1 = "/rbp", SlashCmdList = { OTHER = function() end } } });
		e.start();
		eq(e.G.SLASH_REBORNPLANNER1, "/rebornplanner", "free alias still registered");
		eq(e.G.SLASH_OTHER1, "/rbp", "the other addon's alias is untouched");
		ok(e.world.chat[1] and e.world.chat[1]:find("/rbp", 1, true), "player is told");
		local e2 = boot({ noStart = true, preset = { SLASH_A1 = "/rbp", SLASH_B1 = "/rebornplanner" } });
		e2.start();
		eq(e2.G.SlashCmdList.REBORNPLANNER, nil, "both taken: nothing registered");
	end);

	test("3A: /rbp opens and closes; /rbp diag and unknown arguments answer", function()
		local e = boot();
		local root = e.open();
		ok(root:IsShown());
		e.G.SlashCmdList.REBORNPLANNER("");
		no(root:IsShown());
		e.G.SlashCmdList.REBORNPLANNER("toggle");
		ok(root:IsShown());
		e.G.SlashCmdList.REBORNPLANNER("diag");
		ok(e.world.chat[#e.world.chat - 2]:find("storage CREATED", 1, true), e.world.chat[#e.world.chat - 2]);
			ok(e.world.chat[#e.world.chat]:find("bijoux :", 1, true));
		e.G.SlashCmdList.REBORNPLANNER("what");
		ok(e.world.chat[#e.world.chat]:find("Usage", 1, true));
		eq(e.root.strata, "FULLSCREEN_DIALOG", "fantasy theme must remain above the game HUD");
		ok(e.root.clamped, "window is clamped to the screen");
	end);

	test("3A: language follows the client (frFR French, enUS and others English)", function()
		local fr = boot({ locale = "frFR" }); fr.open();
		ok(fr.world.hasText("Importer") and fr.world.hasText("Créer un build"), fr.texts());
		local en = boot({ locale = "enUS" }); en.open();
		ok(en.world.hasText("Search:") and en.world.hasText("Create a build"));
		local de = boot({ locale = "deDE" }); de.open();
		ok(de.world.hasText("Suchen:"), "German has a starter translation");
		ok(de.world.hasText("Create a build") == false, "translated navigation label is used");
		-- the saved choice wins over the client locale
		local e = boot({ locale = "frFR" });
		e.h():SetSetting("lang", "enUS");
		local again = reload(e, { locale = "frFR" }); again.open();
		ok(again.world.hasText("Search:"));
	end);

	test("3A: read-only storage (future schema): nothing is replaced, editing is blocked, the player is told", function()
		local fut = { schema = 99, keep = "me" };
		local e = boot({ preset = { RebornBuildPlannerDB = fut } });
		ok(e.G.RebornBuildPlannerDB == fut, "a newer database must stay untouched");
		e.open();
		ok(e.world.hasText("Read only"), e.texts());
		no(e.ui.lib.create:IsEnabled());
		e.c:Create("x", "warrior");
		eq(fut, { schema = 99, keep = "me" });
		eq(e.c:Handle().readOnly, true);
	end);

	test("3A: pre-existing prototype data is migrated and the migrated table is assigned", function()
		local old = { builds = { { name = "Old", class = "warrior", spells = { "whirlwind" } } } };
		local e = boot({ preset = { RebornBuildPlannerDB = old } });
		ok(e.G.RebornBuildPlannerDB ~= old);
		eq(e.G.RebornBuildPlannerDB.schema, 1);
		e.open();
		ok(e.world.hasText("Old"));
	end);

	-- ------------------------------------------------------------------ 3B: library
	test("3B: empty state, create, appears in the list, never active by itself", function()
		local e = boot({ classToken = "MAGE", className = "Mage" }); e.open();
		ok(e.world.hasText("No build yet"));
		ok(e.world.hasText("Create one"));
		local id = createViaUI(e, "Frost plan");
		ok(id);
		eq(e.h():Get(id).class, "mage", "default class = the player's class");
		eq(e.h():Get(id).name, "Frost plan");
		eq(e.c.state.view, "editor", "the new build opens in the editor");
		eq(e.h():GetActive("mage"), nil, "creating never activates");
	end);

	test("3B: empty editor has no floating separators, hidden slots or inspector lines", function()
		local e = boot(); e.open();
		ok(e.ui.ed.empty:IsShown());
		ok(e.ui.ed.emptyMark:IsShown() and e.ui.ed.emptyHint:IsShown(), "centered empty state present");
		ok(e.ui.ed.emptyCreate:IsShown(), "central create build action available");
		no(e.ui.ed.spellHead.rule:IsShown(), "spell line hidden with title");
		no(e.ui.ed.equipHead.rule:IsShown(), "equipment line hidden with title");
		no(e.ui.ed.nt.head.rule:IsShown(), "advanced section separator hidden");
		no(e.ui.det.head.rule:IsShown(), "detail separator hidden");
		for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
			no(e.ui.ed.groups[g].sep:IsShown(), g .. " vertical guide hidden");
		end
		local id = e.c:Create("Existing build", "warrior");
		e.ui:OpenEditor(id);
		no(e.ui.ed.emptyCreate:IsShown(), "empty-state CTA removed when editing");
		ok(e.ui.ed.spellHead.rule:IsShown(), "spell line restored after opening build");
		ok(e.ui.ed.equipHead.rule:IsShown(), "equipment line restored after opening build");
		for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
			ok(e.ui.ed.groups[g].sep:IsShown(), g .. " vertical guide restored");
		end
		e.c:CloseEditor();
		no(e.ui.ed.spellHead.rule:IsShown(), "spell divider hidden again");
	end);

	test("3B: new-build modal input and class arrows sit above the opaque window", function()
		local e = boot({ classToken = "MAGE", className = "Mage" }); e.open();
		e.ui:AskCreate();
		local m = e.ui.modal;
		ok(m.form and m.form:IsShown(), "separate high-level form exists");
		ok(m.form:GetFrameLevel() > m:GetFrameLevel(), "form above opaque modal");
		ok(m.edit:IsShown() and m.edit:GetFrameLevel() > m.form:GetFrameLevel(), "visible input above form");
		ok(m.editSurface and m.editSurface:IsShown(), "visible inset behind input");
		ok(m.editSurface:GetFrameLevel() < m.edit:GetFrameLevel(), "field in front of its inset");
		ok(m.cycle.prev:IsShown() and m.cycle.next:IsShown(), "both class arrows available");
		ok(m.cycle.prev:GetFrameLevel() > m.form:GetFrameLevel(), "previous arrow above surface");
		ok(m.cycle.next:GetFrameLevel() > m.form:GetFrameLevel(), "next arrow above surface");
		local starting = m.class;
		e.world.click(m.cycle.next);
		no(m.class == starting, "cycler changes class in create modal");
		e.world.type(m.edit, "Mage test");
		e.world.click(m.b[1]);
		local created = e.c.state.selectedId;
		ok(created ~= nil, "button submits entered name");
		eq(e.h():Get(created).name, "Mage test");
		eq(e.h():Get(created).class, m.class);
	end);

	local function populate(e)
		local ids = {};
		for _, spec in ipairs({ { "W one", "warrior" }, { "W two", "warrior" }, { "M one", "mage" }, { "R one", "rogue" } }) do
			ids[#ids + 1] = e.c:Create(spec[1], spec[2]);
		end
		e.c:SetView("library");
		return ids;
	end

	test("3B: list, class filter, selection, pages", function()
		local e = boot(); e.open();
		local ids = populate(e);
		ok(e.world.hasText("W one") and e.world.hasText("M one") and e.world.hasText("R one"));
		e.world.click(e.ui.lib.classButton);
		ok(e.ui.lib.classMenu:IsShown(), "class dropdown opens");
		local keys = e.c:ClassKeys();
		local warriorIndex = nil;
		for i, key in ipairs(keys) do if key == "warrior" then warriorIndex = i + 1; end end
		ok(warriorIndex, "warrior is selectable");
		e.world.click(e.ui.lib.classOptions[warriorIndex]);
		eq(e.c.state.classFilter, "warrior");
		ok(e.world.hasText("W two") and not e.world.hasText("M one"), e.texts());
		no(e.ui.lib.classMenu:IsShown(), "class dropdown closes on selection");
		e.world.click(e.ui.lib.classButton);
		e.world.click(e.ui.lib.classOptions[1]);
		eq(e.c.state.classFilter, nil);
		for _ = 1, 20 do e.c:Create("many", "paladin"); end
		e.c:SetView("library");
		local _, off, max = e.c:LibView();
		ok(max > 0, "more builds than rows: the list scrolls instead of paging");
		e.c:ScrollLib(3);
		eq(e.c.state.libOffset, 3);
		e.c:ScrollLib(1000);
		eq(e.c.state.libOffset, max, "clamped");
		e.world.click(e.ui.lib.rows[1]);
		eq(e.c.state.selectedId, e.ui.lib.rows[1].rowId);
	end);

	test("3B: class artwork, readable class colors and per-row favorite hearts", function()
		local e = boot(); e.open();
		local ids = populate(e);
		local lib, visuals = e.ui.lib, e.ns.ClassVisual;
		local first = lib.rows[1];
		ok(first.classIcon and first.classIcon.texture, "class texture assigned to row");
		ok(first.star.tex and first.star.tex.texture:find("ultimate_fav_off", 1, true),
			"outline heart means not favourite");
		local d = first.rowData;
		local r, g, b = visuals.Color(d.class);
		eq(first.name.color, { r, g, b }, "name uses appropriate class color");
		local rowId = first.rowId;
		e.world.click(first.star);
		eq(e.h():Meta(rowId).fav, true, "heart toggles favourite without selecting build");
		ok(e.ui.lib.rows[1].star.tex.texture:find("ultimate_fav_on", 1, true),
			"filled heart is displayed after favorite click");
		local path = visuals.Icon("demonhunter", e.c:Catalog());
		eq(path, "Interface\\AddOns\\RebornBuildPlanner\\Media\\ultimate_class_dh", "demon-hunter icon is bundled and deterministic");
		local monk = visuals.Icon("monk", e.c:Catalog());
		eq(monk, "Interface\\AddOns\\RebornBuildPlanner\\Media\\ultimate_class_monk", "monk icon is bundled and deterministic");
	end);

	test("3B: banish-after remains a requested spell with distinct red editor/browser treatment", function()
		local e = boot(); e.open();
		local id = e.c:Create("Later ban", "warrior");
		e.ui:OpenEditor(id);
		local spell = e.c:Catalog():SpellsOfClass("warrior")[1];
		ok(spell, "class spell available");
		e.c:AddSpell(spell);
		e.c:ToggleBanishAfter(spell);
		local row = e.ui.ed.spells[1];
		ok(row.afterMark:IsShown(), "editor red strip shown");
		eq(row.tog.role, "danger", "red banish-after action");
		ok(row.bg and row.bg:IsShown(), "editor keeps a visible background");
		local found;
		for _, r in ipairs(e.ui.bs.rows) do
			if r.tipKey == spell then found = r; break end
		end
		ok(found, "requested spell appears in browser");
		ok(found.afterMark:IsShown(), "browser red strip shown");
		ok(found.tag.text:find("Banish after", 1, true), "browser explicitly states banish after");
		e.c:ToggleBanishAfter(spell);
		no(row.afterMark:IsShown(), "editor strip removed after toggle");
		no(found.afterMark:IsShown(), "browser strip removed after toggle");
	end);

	test("3B: sort dropdown saves selection; all menu choices are direct and close on outside click", function()
		local e = boot(); e.open(); populate(e);
		local lib = e.ui.lib;
		e.world.click(lib.sortButton);
		ok(lib.sortMenu:IsShown() and lib.dismiss:IsShown());
		eq(#lib.sortOptions, 5);
		e.world.click(lib.sortOptions[5]); -- class
		eq(e.c:Sort(), "class");
		eq(e.h():GetSetting("libSort"), "class");
		no(lib.sortMenu:IsShown());
		e.world.click(lib.sortButton);
		e.world.click(lib.dismiss);
		no(lib.sortMenu:IsShown(), "outside click dismisses menu");
		e.world.click(lib.sortButton);
		e.world.click(lib.sortOptions[2]); -- created
		eq(e.c:Sort(), "created");
		eq(e.h():GetSetting("libSort"), "created");
	end);

	test("3B: duplicate, rename, activate / stop following, status shown", function()
		local e = boot(); e.open();
		local ids = populate(e);
		e.c:Select(ids[1]);
		e.world.clickLabel(T(e, "Duplicate"), e.ui.leftPanel);
		eq(#e.h():List("warrior"), 3);
		ok(e.world.hasText("W one (copy)"));
		e.c:Select(ids[1]);
		e.world.clickLabel(T(e, "Rename"), e.ui.leftPanel);
		e.world.type(e.G.RebornBuildPlannerModalEdit, "Renamed é");
		modalButton(e, T(e, "Rename"));
		eq(e.h():Get(ids[1]).name, "Renamed é");
		e.c:Select(ids[1]);
		e.world.clickLabel(T(e, "Follow"), e.ui.leftPanel);
		eq(e.h():GetActive("warrior"), ids[1]);
		ok(e.world.hasText("Active"), e.texts());
		e.world.clickLabel(T(e, "Unfollow"), e.ui.leftPanel);
		eq(e.h():GetActive("warrior"), nil);
		-- cancelling a prompt changes nothing
		e.c:Select(ids[1]);
		e.world.clickLabel(T(e, "Rename"), e.ui.leftPanel);
		e.world.type(e.G.RebornBuildPlannerModalEdit, "never");
		modalButton(e, T(e, "Cancel"));
		eq(e.h():Get(ids[1]).name, "Renamed é");
	end);

	test("3B: deletion needs a confirmation, can be undone, is explained, and restores from the trash", function()
		local e = boot(); e.open();
		local ids = populate(e);
		e.c:Select(ids[3]);
		e.world.clickLabel(T(e, "Delete"), e.ui.leftPanel);
		ok(e.G.RebornBuildPlannerModal:IsShown());
		ok(e.G.RebornBuildPlannerModal.body.text:find("20", 1, true), "the trash policy is explained: " .. e.G.RebornBuildPlannerModal.body.text);
		modalButton(e, T(e, "Cancel"));
		ok(e.h():Get(ids[3]), "cancel keeps the build");
		e.world.clickLabel(T(e, "Delete"), e.ui.leftPanel);
		modalButton(e, T(e, "Delete"));
		eq(e.h():Get(ids[3]), nil);
		ok(e.world.hasText("moved to the trash"));
		ok(e.world.button(T(e, "Undo the deletion")), "undo offered");
		e.world.clickLabel(T(e, "Undo the deletion"));
		ok(e.h():Get(ids[3]));
		-- again, then restore from the trash view
		e.c:Select(ids[3]);
		e.world.clickLabel(T(e, "Delete"), e.ui.leftPanel);
		modalButton(e, T(e, "Delete"));
		e.world.clickLabel(T(e, "Trash"));
		ok(e.world.hasText("M one") and e.world.hasText("Deleted"), e.texts());
		e.c:Select(ids[3]);
		e.world.clickLabel(T(e, "Restore"), e.ui.leftPanel);
		ok(e.h():Get(ids[3]));
		eq(e.c.state.trashMode, false);
	end);

	test("3B: a full trash warns before and after, naming what is lost", function()
		local e = boot(); e.open();
		for i = 1, e.ns.Storage.LIMITS.trash do
			local id = e.c:Create("t" .. i, "warrior");
			e.c:ConfirmDelete(id);
		end
		e.c:SetView("library");
		local victim = e.c:Create("fresh", "warrior");
		e.c:Select(victim);
		e.world.clickLabel(T(e, "Delete"), e.ui.leftPanel);
		ok(e.G.RebornBuildPlannerModal.body.text:find("full", 1, true), e.G.RebornBuildPlannerModal.body.text);
		modalButton(e, T(e, "Delete"));
		ok(e.world.hasText("removed for good"), e.texts());
		ok(e.world.hasText("t1"), "the evicted build is named");
	end);

	test("3B: duplicate and rename are blocked while read-only", function()
		local e = boot({ preset = { RebornBuildPlannerDB = { schema = 99 } } }); e.open();
		for _, b in ipairs({ e.ui.lib.dup, e.ui.lib.rename, e.ui.lib.delete, e.ui.lib.follow, e.ui.lib.create }) do no(b:IsEnabled()); end
	end);

	-- ------------------------------------------------------------------ 3C / 3D: editor, draft, save
	-- selecting a row of the browser, then the detail panel's primary action (what a player does in two clicks)
	local function pick(e, i) e.world.click(e.ui.bs.rows[i]); e.world.click(e.ui.det.act1); end
	local function openNew(e, class)
		e.open();
		local id = e.c:Create("Plan", class or "warrior");
		ok(e.ui:OpenEditor(id) == nil);
		return id, e.ui.ed;
	end

	test("3C: one stage first; six spells maximum; avoid list separate and capped; reorder; remove", function()
		local e = boot(); local id, ed = openNew(e);
		no(e.c:ShowAllPhases());
		no(ed.phaseTabs[2]:IsVisible(), "only one stage by default");
		ok(e.world.hasText("Single stage"));
		local keys = e.ns.catalog:SpellsOfClass("warrior");
		-- the first five come from the catalogue page by one click each, the sixth from page 2
		for i = 1, 5 do pick(e, i); end
		local ph = e.c:Editor().draft.phases[1];
		eq(#ph.spells, 5);
		eq(ph.spells[1].key, keys[1]);
		e.c:AddSpell(keys[6]);
		eq(#e.c:Editor().draft.phases[1].spells, 6);
		-- the seventh spell is refused with a reason, the plan is unchanged
		e.c:AddSpell(keys[7]);
		eq(#e.c:Editor().draft.phases[1].spells, 6);
		ok(e.world.hasText("Limit reached"), e.texts());
		ok(e.world.hasText("6 keep / 0 banish after"), e.texts());
		-- the avoid list is separate, capped, and never consumes a wanted slot
		for i = 7, 9 do ok(e.c:AddBanish(keys[i])); end
		eq(#e.c:Editor().draft.phases[1].banish, 3);
		eq(#e.c:Editor().draft.phases[1].spells, 6);
		ok(e.c:AddBanish(keys[10]) == false);
		eq(#e.c:Editor().draft.phases[1].banish, 3);
		-- a wanted spell cannot go to the avoid list, an avoided one cannot be wanted
		ok(e.c:AddBanish(keys[1]) == false);
		ok(e.world.hasText("remove it from the plan first"), e.texts());
		ok(e.c:AddSpell(keys[7]) == false);
		-- order
		e.world.click(ed.spells[2].up);
		eq(e.c:Editor().draft.phases[1].spells[1].key, keys[2]);
		no(ed.spells[1].up:IsEnabled());
		no(ed.spells[6].down:IsEnabled());
		e.world.click(ed.spells[1].down);
		eq(e.c:Editor().draft.phases[1].spells[1].key, keys[1]);
		e.world.click(ed.spells[1].del);
		eq(#e.c:Editor().draft.phases[1].spells, 5);
		ok(e.world.hasText("Spells to acquire, by priority (5/6)"), e.texts());
		-- Notes open read-only; the avoid-list editor is an explicit second step.
		e.c:ToggleAdvanced();
		ok(ed.nt.previewNotes:IsShown(), "advanced opens the notes overview");
		no(ed.nt.notes.scroll:IsShown(), "editor stays hidden until requested");
		e.world.click(ed.nt.switch);
		ok(ed.nt.avoid[1].frame:IsShown());
		e.world.click(ed.nt.avoid[1].del);
		eq(#e.c:Editor().draft.phases[1].banish, 2);
	end);

	test("3C: an empty spell row offers '+ Add a spell' and points the catalogue at spells", function()
		local e = boot(); local id, ed = openNew(e);
		e.c:SetCatalog("rings");
		eq(e.c:Editor().cat, "rings");
		ok(ed.spells[1].add:IsVisible(), "empty row shows the add button");
		e.world.click(ed.spells[1].add);
		eq(e.c:Editor().cat, "spells");
		ok(e.world.hasText("Adding to the 6 spells to acquire"), e.texts());
	end);

	test("3C: catalogue is filtered by class and by search; names localised, identifiers are catalogue keys", function()
		local e = boot({ locale = "frFR" }); local id, ed = openNew(e, "warrior");
		for _, entry in ipairs(e.c:CatalogEntries()) do eq(e.ns.catalog:Get("spell", entry.key).class, "warrior"); end
		e.world.type(e.ui.bs.search, "tourb");
		eq(#e.c:CatalogEntries(), 1);
		eq(e.c:CatalogEntries()[1].key, "whirlwind", "found by its French name, stored by key");
		e.world.type(e.ui.bs.search, "whirl");
		eq(#e.c:CatalogEntries(), 1, "English name works too");
		e.world.type(e.ui.bs.search, "zzzz");
		eq(#e.c:CatalogEntries(), 0);
		e.world.type(e.ui.bs.search, "");
		pick(e, 1);
		eq(e.c:Editor().draft.phases[1].spells[1].key, e.ns.catalog:SpellsOfClass("warrior")[1]);
		for _, g in ipairs(e.c:Editor().draft.phases[1].spells) do no(g.key:find(" "), "key is not a display name"); end
		eq(e.c:Editor().draft.phases[1].label, "", "default stage label stays empty");
	end);

	test("3C: equipment on one page: every slot visible, click a slot -> catalogue and target follow, direct replacement", function()
		local e = boot(); local id, ed = openNew(e);
		-- all twelve slots are on screen at once, with main / alternative roles
		for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
			for j, cell in ipairs(ed.groups[g].cells) do ok(cell:IsVisible(), g .. j); end
		end
		ok(e.world.hasText("Main 1") and e.world.hasText("Alt. 1"), e.texts());
		-- Long status labels have reserved space rather than overlapping the item name.
		ok(e.ui.bs.rows[1].tag:GetWidth() >= 98, "browser status column is legible");
		ok(e.ui.bs.rows[1].name:GetWidth() <= 200, "browser item title does not overlap its status");
		-- clicking an empty alternative ring slot: catalogue = rings, target = that slot, visible
		e.world.click(ed.groups.rings.cells[3]);
		eq(e.c:Editor().cat, "rings");
		ok(e.world.hasText("Target: Rings - Alternative 1 (empty)"), e.texts());
		pick(e, 1);                               -- Place
		local rings = e.c:Editor().draft.phases[1].rings;
		eq(rings[1], ""); eq(rings[2], ""); ok(rings[3] ~= ""); eq(rings[4], "");
		local first = rings[3];
		-- the same piece cannot be placed twice; the catalogue says so
		e.world.click(ed.groups.rings.cells[1]);
		e.world.click(e.ui.bs.rows[1]);
		no(e.ui.det.act1:IsEnabled(), "a piece already placed cannot be placed twice");
		-- placing in the chosen slot only
		pick(e, 2);
		eq(e.c:Editor().draft.phases[1].rings[1], e.c:CatalogEntries()[2].key);
		eq(e.c:Editor().draft.phases[1].rings[3], first, "other slots untouched");
		-- direct replacement: select a filled slot, place another piece, no manual emptying
		e.world.click(ed.groups.rings.cells[1]);
		local before = e.c:Editor().draft.phases[1].rings[1];
		pick(e, 3);
		local after = e.c:Editor().draft.phases[1].rings[1];
		ok(after ~= before and after ~= "", "slot replaced in one click");
		-- clear
		e.world.click(ed.groups.rings.cells[3].x);
		eq(e.c:Editor().draft.phases[1].rings[3], "");
		ok(e.c:Editor().draft.phases[1].rings[1] ~= "");
		-- trinkets and amulets: the filter button picks the first empty main slot
		e.world.click(e.ui.bs.kinds.amulets);
		eq(e.c:Editor().slot, 1);
		for _, en in ipairs(e.c:CatalogEntries()) do
			local a = e.ns.catalog:Get("amulet", en.key);
			ok(a.class == "warrior" or (a.classes ~= nil and (#a.classes == 0 or U.IndexOf(a.classes, "warrior"))), "class-filtered amulets and legends");
		end
		pick(e, 1);
		ok(e.c:Editor().draft.phases[1].amulets[1] ~= "");
		e.world.click(e.ui.bs.kinds.trinkets);
		pick(e, 1);
		ok(e.c:Editor().draft.phases[1].trinkets[1] ~= "");
		ok(e.c:EditorReport().clean);
	end);

	test("3C: notes, link, talents (advanced block); kept data is listed and never dropped by a save", function()
		local e = boot(); local id, ed = openNew(e);
		e.c:ToggleAdvanced();
		ok(ed.nt.previewNotes:IsShown(), "notes overview is visible first");
		no(ed.nt.notes.surround:IsShown(), "edit field frame cannot cover the note preview");
		e.world.click(ed.nt.switch);
		ok(ed.nt.notes.surround:IsShown(), "notes edit frame is shown only in edit mode");
		ok(ed.nt.notes.scroll:IsShown(), "editable notes require an explicit click");
		e.world.type(ed.nt.notes, "Ligne 1\nLigne 2 \195\169");
		e.world.type(ed.nt.link, "https://azreborn.com/planner/warrior");
		e.world.type(ed.nt.talents, "10203-000-0110");
		local d = e.c:Editor().draft;
		eq(d.phases[1].notes, "Ligne 1\nLigne 2 \195\169");
		eq(d.phases[1].link, "https://azreborn.com/planner/warrior");
		eq(d.talents, "10203-000-0110");
		e.world.click(ed.nt.switch);
		ok(ed.nt.previewNotes:GetText():find("Ligne 1",1,true), "overview displays saved draft notes");
		no(ed.nt.notes.surround:IsShown(), "notes preview remains readable after editing");
		ok(ed.nt.readingMatte:IsShown(), "note preview has its own opaque reading surface");
		ok(ed.nt.previewLink:IsShown(), "existing link is available in the overview");
		e.world.click(ed.nt.previewLink);
		ok(ed.nt.link:IsShown(), "URL is selectable for Ctrl+C without an unsupported browser API");
		ok(e.world.hasText("No hidden data"));
		-- an imported build with hidden data (stats, rank goal, ext, 2nd stage)
		local raw = { name = "Rich", class = "warrior", phases = { { spells = { { key = "whirlwind", mode = "rank", rank = 3 } }, stats = { damage = 50 }, notes = "n" },
			{ spells = { "execute" } } }, mystery = { 1 } };
		local rid = e.h():Add(raw);
		e.c.state.editor = nil;
		e.ui:OpenEditor(rid);
		ok(e.c:ShowAllPhases(), "an imported build with several stages shows them at once");
		ok(ed.phaseTabs[2]:IsVisible());
		e.c:ToggleAdvanced();
		e.world.click(ed.nt.switch);
		local hidden = e.c:HiddenData();
		ok(#hidden >= 2, "hidden data listed: " .. H.fmt(hidden));
		ok(e.world.hasText("kept"), e.texts());
		e.c:SetNotes("changed");
		e.world.clickLabel(T(e, "Save"), e.ui.views.editor);
		local saved = e.h():Get(rid);
		eq(saved.phases[1].stats, { damage = 50 });
		eq(saved.phases[1].spells[1], { key = "whirlwind", mode = "rank", rank = 3 });
		eq(saved.ext.mystery, { 1 });
		eq(saved.phases[2].spells[1].key, "execute");
		eq(saved.phases[1].notes, "changed");
		-- four imported stages stay four after a save
		eq(#saved.phases, 4);
	end);

	test("3D: draft versus saved, statuses, save, discard, follow, repair", function()
		local e = boot(); local id, ed = openNew(e);
		ok(e.world.hasText("Saved"), e.texts());
		no(ed.save:IsEnabled(), "nothing to save yet");
		pick(e, 1);
		ok(e.world.hasText("Unsaved changes"), e.texts());
		eq(e.h():Get(id).phases[1].spells[1], nil, "storage untouched until Save");
		e.world.click(ed.revert);
		eq(#e.c:Editor().draft.phases[1].spells, 0);
		ok(e.world.hasText("Saved"));
		pick(e, 1);
		e.world.click(ed.save);
		eq(#e.h():Get(id).phases[1].spells, 1);
		eq(e.h():Get(id).revision, 2);
		eq(e.h():GetActive("warrior"), nil, "saving does not follow");
		pick(e, 2);
		e.world.click(ed.follow);
		eq(e.h():GetActive("warrior"), id);
		eq(#e.h():Get(id).phases[1].spells, 2);
		ok(e.world.hasText("Saved and followed"), e.texts());
		-- a build to repair: saved, never followed
		local raw = { name = "Broken", class = "warrior", phases = { { spells = { "whirlwind" }, banish = { "whirlwind" } } } };
		local rid = e.h():Add(raw);
		e.c.state.editor = nil;
		e.ui:OpenEditor(rid);
		ok(e.world.hasText("Needs repair"), e.texts());
		pick(e, 3);              -- an unrelated change
		ok(e.world.hasText("Unsaved changes | Needs repair"), e.texts());
		e.world.click(ed.follow);
		eq(e.h():GetActive("warrior"), id, "the previous active build stays");
		ok(e.world.hasText("not followed"), e.texts());
		ok(e.h():Get(rid).phases[1].banish[1] == "whirlwind", "conflict kept as data");
		e.c:RemoveBanish("whirlwind");
		e.world.click(ed.follow);
		eq(e.h():GetActive("warrior"), rid, "repaired: follow works");
	end);

	test("3D: switching build / closing with unsaved changes asks; Escape never discards; no implicit save", function()
		local e = boot(); local id, ed = openNew(e);
		local other = e.c:Create("Other", "warrior");
		pick(e, 1);
		ok(U.IndexOf(e.G.UISpecialFrames, "RebornBuildPlannerFrame") == nil, "dirty editor: Escape must not close the window");
		eq(e.world.escape(), false);
		ok(e.root:IsShown());
		-- clicking another build in the library -> prompt -> keep editing
		local function rowOf(bid) for _, r in ipairs(e.ui.lib.rows) do if r.rowId == bid and r:IsShown() then return r; end end end
		e.world.click(rowOf(other));
		ok(e.G.RebornBuildPlannerModal:IsShown());
		ok(e.world.hasText("Unsaved changes"));
		modalButton(e, T(e, "Keep editing"));
		eq(e.c:Editor().id, id);
		eq(#e.c:Editor().draft.phases[1].spells, 1);
		-- Escape in the dialog = keep editing
		e.world.click(rowOf(other));
		eq(U.IndexOf(e.G.UISpecialFrames, "RebornBuildPlannerModal") ~= nil, true);
		ok(e.world.escape());
		no(e.G.RebornBuildPlannerModal:IsShown());
		eq(e.c:Editor().id, id);
		-- discard: the other build opens, the draft is gone
		e.world.click(rowOf(other));
		modalButton(e, T(e, "Discard"));
		eq(e.c:Editor().id, other);
		eq(#e.h():Get(id).phases[1].spells, 0, "discarded");
		-- save from the prompt
		e.ui:OpenEditor(id);
		pick(e, 1);
		e.world.click(rowOf(other));
		modalButton(e, T(e, "Save"));
		eq(e.c:Editor().id, other);
		eq(#e.h():Get(id).phases[1].spells, 1);
		-- closing the WINDOW with changes asks as well
		e.ui:OpenEditor(id);
		pick(e, 2);
		e.G.SlashCmdList.REBORNPLANNER("");
		ok(e.root:IsShown() and e.G.RebornBuildPlannerModal:IsShown(), "/rbp on a dirty editor asks first");
		modalButton(e, T(e, "Keep editing"));
		ok(e.root:IsShown());
		e.world.click(e.G.RebornBuildPlannerClose);
		modalButton(e, T(e, "Discard"));
		no(e.root:IsShown());
		eq(#e.h():Get(id).phases[1].spells, 1);
		-- clean editor: Escape closes the window
		e.G.SlashCmdList.REBORNPLANNER("");
		ok(U.IndexOf(e.G.UISpecialFrames, "RebornBuildPlannerFrame") ~= nil);
		ok(e.world.escape());
		no(e.root:IsShown());
		eq(#e.G.UISpecialFrames, 0, "no stale special frame left behind");
	end);

	test("3D: a draft survives hiding the window and is lost only on /reload (never auto-saved)", function()
		local e = boot(); local id, ed = openNew(e);
		pick(e, 1);
		e.root:Hide();
		e.G.SlashCmdList.REBORNPLANNER("");
		ok(e.c:EditorDirty());
		local again = reload(e);
		eq(#again.h():Get(id).phases[1].spells, 0, "unsaved draft is not in the saved data");
	end);

	test("3D: editing is refused in read-only mode", function()
		local e = boot();
		e.open();
		local id = e.c:Create("x", "warrior");
		e.ui:OpenEditor(id);
		e.h().readOnly = true; e.h().status = "REPAIR_REFUSED";
		eq(e.c:AddSpell("whirlwind"), false);
		ok(e.world.hasText("Read only"));
		no(e.ui.ed.save:IsEnabled());
	end);

	test("3D: unknown class: stored, editable list empty, never followed", function()
		local e = boot(); e.open();
		local id = e.h():Add({ name = "Future", class = "necromancer", phases = {} });
		e.c:Select(id);
		e.c:SetView("library");
		e.ui:OpenEditor(id);
		eq(#e.c:CatalogEntries(), 0);
		ok(e.world.hasText("necromancer"));
		e.c:SetName("Future 2");
		e.world.click(e.ui.ed.follow);
		eq(e.h():GetActive("necromancer"), nil);
		eq(e.h():Get(id).name, "Future 2");
	end);

	-- ------------------------------------------------------------------ 3E: import / export
	local GOOD, CONFLICT;
	do
		local ns0 = H.loadAddon();
		local C, J, B = ns0.PlannerCodec, ns0.Json, ns0.Base64Url;
		local function code(a) return C.PREFIX .. B.Encode(assert(J.Encode(a))); end
		local function phase(spells, banish, rings) return J.Array({ "", J.Array(spells), J.Array(banish or {}), J.Array(rings or {}) }); end
		GOOD = code(J.Array({ 1, "Imported \195\169", "warrior", "10-0-0", phase({ "whirlwind", "execute" }, { "rend" }, { "accuria", "", "quick_strike" }), J.Array({ "Mid", J.Array({ "cleave" }) }) }));
		CONFLICT = code(J.Array({ 1, "Conflicted", "warrior", "", phase({ "whirlwind", "death_coil" }, { "whirlwind" }) }));
	end

	local function analyze(e, text)
		e.c:SetView("import");
		e.world.type(e.ui.im.box, text);
		e.world.clickLabel(T(e, "Analyze"), e.ui.views.import);
	end

	test("3E: import with preview; nothing is saved before Import; the new build is not active", function()
		local e = boot(); e.open();
		local before = e.h():Counts().builds;
		analyze(e, GOOD);
		ok(e.world.hasText("Imported \195\169"), e.texts());
		ok(e.world.hasText("Locally valid"),"decoded build validated locally");
		ok(e.world.hasText("Whirlwind") and e.world.hasText("Execute"),"spell goals shown");
		ok(e.ui.im.classCycle.label:GetText():find("1/4",1,true),"first phase shown");
		ok(e.ui.im.nameEdit:GetText() == "Imported \195\169","decoded build name is prefilled");
		eq(e.h():Counts().builds, before, "preview must not save");
		e.world.clickLabel(T(e, "Import"), e.ui.views.import);
		eq(e.h():Counts().builds, before + 1);
		local id = e.c.state.selectedId;
		eq(e.h():Get(id).name, "Imported \195\169");
		eq(e.h():GetActive("warrior"), nil);
		eq(e.c.state.view, "editor");
		ok(e.world.hasText("Imported (not active)"), e.texts());
		eq(e.c:ImportState(), nil);
	end);

	test("3E: review immediately shows spells, bans and equipment without item pagination", function()
		local e=boot();e.open();
		local prior=e.h():Counts().builds;
		analyze(e,GOOD);
		ok(e.ui.im.classCycle.label:IsShown(),"phase selector available");
		ok(not e.ui.im.box.scroll:IsShown(),"pasted code hidden during review");
		ok(not e.ui.rightPanel:IsShown(),"browser hidden during import review");
		local rows=e.ui.im.detailRows;
		local function hasRow(term)
			for _,row in ipairs(rows) do
				if row.label:GetText():find(term,1,true) then return true end
			end
			return false
		end
		ok(hasRow("Whirlwind"),"first spell visible by name");
		ok(hasRow("Execute"),"second spell visible by name");
		ok(e.world.hasText("Rend"),"banish target visible");
		ok(e.world.hasText("Accuria"),"equipped ring visible");
		eq(e.h():Counts().builds,prior,"review does not write to SavedVariables");
		e.world.click(e.ui.im.classCycle.next);
		ok(e.ui.im.classCycle.label:GetText():find("2/4",1,true),"next phase opens");
		e.world.click(e.ui.im.paste);
		ok(e.ui.im.box.scroll:IsShown(),"Edit code returns to input");
		ok(not e.ui.im.commit:IsShown(),"confirmation is hidden while editing code");
		ok(e.ui.im.analyze:IsShown(),"Analyze is shown while editing the code");
		ok(not e.ui.im.classCycle.label:IsShown(),"review controls hidden in input step");
	end);

	test("3E: a build with conflicts previews its problems and imports as 'needs repair', not followable", function()
		local e = boot(); e.open();
		analyze(e, CONFLICT);
		ok(e.world.hasText("Importable, needs repair"), e.texts());
		ok(e.world.hasText("Conflict"), e.texts());
		ok(e.world.hasText("another class"), e.texts());
		e.world.clickLabel(T(e, "Import"), e.ui.views.import);
		local id = e.c.state.selectedId;
		ok(e.world.hasText("needs repair"), e.texts());
		e.c:Activate(id);
		eq(e.h():GetActive("warrior"), nil);
		ok(e.world.hasText("repair"), e.texts());
	end);

	test("3E: a refused text changes nothing and says why", function()
		local e = boot(); e.open();
		e.c:Create("keep", "warrior");
		local snap = U.DeepCopy(e.h().db);
		for _, bad in ipairs({ "azsb1:!!!!", "", "https://azreborn.com/planner/warrior", "azsb1:" .. e.ns.Base64Url.Encode("[2,\"x\",\"warrior\"]") }) do
			analyze(e, bad);
			ok(e.world.hasText("Cannot import this text"), "for " .. bad .. ": " .. e.texts());
			no(e.ui.im.commit:IsEnabled());
		end
		no(e.ui.im.commit:IsShown(),"invalid code cannot display the confirmation action");
		ok(H.deepeq(snap, e.h().db), "refused import mutated storage");
	end);

	test("3E: talents-only link needs a class; the class comes from the path when it can", function()
		local e = boot(); e.open();
		analyze(e, "https://azreborn.com/planner?b=1-2-3");
		ok(e.world.hasText("Choose a class"), e.texts());
		no(e.ui.im.commit:IsEnabled());
		e.world.click(e.ui.im.classCycle.next);
		ok(e.ui.im.commit:IsEnabled());
		e.world.click(e.ui.im.commit);
		eq(e.h():Get(e.c.state.selectedId).talents, "1-2-3");
		analyze(e, "https://azreborn.com/planner/rogue?b=0-1-2");
		ok(e.ui.im.commit:IsEnabled());
		ok(e.world.hasText("Rogue") or e.world.hasText("rogue") or e.world.hasText("Talent string"), e.texts());
	end);

	test("UI and HUD background opacity is independent, fully adjustable, and leaves contents opaque", function()
		local e=boot();e.open();
		e.world.click(e.ui.uiAlphaMinus);
		eq(e.h():GetSetting("windowOpacity"),.9);
		eq(e.ui.root.nine.tex[9].alpha,.9,"window background fades");
		ok(e.ui.root.alpha==nil or e.ui.root.alpha==1,"window parent remains opaque");
		ok(e.ui.root.nine.tex[1].alpha==nil or e.ui.root.nine.tex[1].alpha==1,"window decorative border not dimmed");
		e.world.click(e.ui.hudAlphaMinus);
		eq(e.h():GetSetting("trackerOpacity"),.9);
		eq(e.h():GetSetting("windowOpacity"),.9);
		for i=1,12 do e.world.click(e.ui.uiAlphaMinus);e.world.click(e.ui.hudAlphaMinus) end
		eq(e.h():GetSetting("windowOpacity"),0);
		eq(e.h():GetSetting("trackerOpacity"),0);
		eq(e.ui.root.nine.tex[9].alpha,0,"window centre invisible at zero");
		ok(e.ui.root.alpha==nil or e.ui.root.alpha==1,"buttons and labels stay opaque at zero");
		for i=1,12 do e.world.click(e.ui.uiAlphaPlus);e.world.click(e.ui.hudAlphaPlus) end
		eq(e.h():GetSetting("windowOpacity"),1);
		eq(e.h():GetSetting("trackerOpacity"),1);
		eq(e.ui.root.nine.tex[9].alpha,1);
	end);

	test("3E: import field is visibly framed and paste button focuses the input", function()
		local e=boot();e.open();
		e.world.click(e.ui.nav.import);
		ok(e.ui.im.box.surround and e.ui.im.box.surround.backdrop,
		  "import has a visible native-framed clipboard field");
		ok(e.ui.im.box:IsShown(),"paste edit box available before Analyze");
		e.world.click(e.ui.im.paste);
		ok(e.ui.im.box:HasFocus(),"paste button focuses the multiline EditBox");
		e.ui.im.box:SetText("azsb1:sample");
		eq(e.ui.im.box:GetText(),"azsb1:sample");
	end);

	test("3E: export without loss shows a selectable code that imports back", function()
		local e = boot(); e.open();
		local id = e.c:Create("Export me", "mage");
		local b = e.h():Get(id);
		b = e.ns.BuildModel.AddSpell(b, 1, "frostbolt", nil, e.ns.catalog);
		b = e.ns.BuildModel.SetSlot(b, 1, "rings", 2, "accuria", e.ns.catalog);
		ok(e.h():Update(id, b));
		e.c:SetView("library");
		e.c:Select(id);
		e.ui:OpenEditor(id);
		e.world.click(e.ui.nav.export);
		eq(e.c.state.view, "export");
		local box = e.ui.ex.box;
		ok(box.text:sub(1, 6) == "azsb1:", box.text);
		ok(box:IsVisible());
		ok(e.world.hasText("Nothing of your intent is lost"));
		no(e.ui.ex.accept:IsShown());
		-- the box is a copy source: focusing selects everything; typing is put back
		box:SetFocus();
		ok(box.highlighted);
		ok(e.ui.ex.selectCode:IsShown(),"explicit select-code button shown on export");
		e.world.click(e.ui.ex.selectCode);
		ok(box.highlighted,"select-code control highlights the full export text");
		local code = box.text;
		e.world.type(box, "tampered");
		eq(box.text, code);
		local e2 = boot(); e2.open();
		analyze(e2, code);
		e2.world.clickLabel(T(e2, "Import"), e2.ui.views.import);
		local nb = e2.h():Get(e2.c.state.selectedId);
		eq(nb.phases[1].spells[1].key, "frostbolt");
		eq(nb.phases[1].rings, { "", "accuria", "", "" });
	end);

	test("3E: export with losses lists them, hides the code until accepted, never claims 'lossless'", function()
		local e = boot(); e.open();
		local id = e.h():Add({ name = "Lossy", class = "warrior", futureField = { 1 }, phases = { { spells = { { key = "whirlwind", mode = "rank", rank = 3 }, "death_coil" } } } });
		e.c:Select(id);
		e.ui:OpenEditor(id);
		e.world.click(e.ui.nav.export);
		ok(e.world.hasText("would be lost"), e.texts());
		ok(e.world.hasText("Lost:"), e.texts());
		no(e.ui.ex.box.scroll:IsVisible(), "no code before the losses are accepted");
		ok(e.ui.ex.accept:IsVisible());
		no(e.world.hasText("Nothing of your intent"));
		e.world.click(e.ui.ex.accept);
		ok(e.ui.ex.box.text:sub(1, 6) == "azsb1:");
		ok(e.world.hasText("you accepted"), e.texts());
		-- unknown class: cannot be exported at all
		local uid = e.h():Add({ name = "U", class = "necromancer", phases = {} });
		e.c:PrepareExport(uid, "saved");
		e.c:SetView("export");
		ok(e.world.hasText("cannot be exported"), e.texts());
		no(e.ui.ex.accept:IsVisible());
	end);

	test("3E: native lossless export button exposes a pasteable rbp1 code", function()
		local e=boot();e.open();
		local id=e.c:Create("Native", "hunter");
		e.ui:OpenEditor(id);
		e.world.click(e.ui.nav.export);
		ok(e.ui.ex.native:IsShown(),"native exchange button visible");
		e.world.click(e.ui.ex.native);
		ok(e.ui.ex.box:GetText():sub(1,5)=="rbp1:","native export encoded");
		ok(e.world.hasText("Complete RBP export"),"lossless state is explained");
		no(e.ui.ex.accept:IsShown(),"official loss confirmation hidden for native code");
	end);

	test("3E: exporting the draft reflects unsaved edits and says so", function()
		local e = boot(); local id, ed = openNew(e, "mage");
		pick(e, 1);
		e.world.click(e.ui.nav.export);
		ok(e.world.hasText("draft"), e.texts());
		ok(e.c.state.export.code ~= nil);
		eq(e.h():Get(id).phases[1].spells[1], nil);
	end);

	-- ------------------------------------------------------------------ persistence and window
	test("/reload keeps builds, active build, import results and the window position", function()
		local e = boot(); e.open();
		local id = e.c:Create("Persist", "warrior");
		e.ui:OpenEditor(id);
		pick(e, 1);
		e.world.click(e.ui.ed.follow);
		analyze(e, GOOD);
		e.world.clickLabel(T(e, "Import"), e.ui.views.import);
		e.world.drag(e.root, 40, -20);
		local again = reload(e);
		eq(again.h():Counts().builds, 2);
		eq(again.h():GetActive("warrior"), id);
		eq(again.h():Get(id).phases[1].spells[1].key, e.ns.catalog:SpellsOfClass("warrior")[1]);
		again.open();
		local p = again.root.points[1];
		eq(p.x, 40); eq(p.y, -20);
		ok(again.world.hasText("Persist"));
	end);

	test("window: drag saves the position; a corrupt saved position is ignored and /rbp reset recovers", function()
		local e = boot(); e.open();
		e.world.drag(e.root, -50, 20);
		eq(e.h():GetSetting("window").x, -50);
		e.h().db.settings.window = { point = "TOPLEFT", x = 1e9, y = 5 };
		e.ui:ApplyPosition();
		eq(e.root.points[1].x, 0, "absurd offset falls back to the centre");
		e.h().db.settings.window = { point = "CENTER", x = 300, y = 0 };
		e.ui:ApplyPosition();
		e.G.SlashCmdList.REBORNPLANNER("reset");
		eq(e.root.points[1].x, 0);
		eq(e.h():GetSetting("window"), nil);
		local ok2, err = e.h():SetSetting("window", { point = "CENTER", x = 0 / 0, y = 0 });
		eq(ok2, nil);
	end);

	test("window: scale buttons are bounded and persisted; the window always fits a small screen", function()
		local e = boot({ width = 800, height = 600 }); e.open();
		ok(e.root:GetScale() <= (600 - 24) / 540 + 1e-6, "scale lowered to fit: " .. e.root:GetScale());
		local big = boot({ width = 1365, height = 768 }); big.open();
		eq(big.root:GetScale(), 1);
		big.world.clickLabel(T(big, "Size -"));
		eq(big.h():GetSetting("scale"), 0.9);
		for _ = 1, 10 do big.world.clickLabel(T(big, "Size -")); end
		eq(big.h():GetSetting("scale"), 0.6);
		for _ = 1, 20 do big.world.clickLabel(T(big, "Size +")); end
		eq(big.h():GetSetting("scale"), 1.5);
		ok(big.root:GetScale() <= (768 - 24) / 540 + 1e-6);
	end);

	-- ------------------------------------------------------------------ widgets are created once
	test("no widget is created while the window is used", function()
		local e = boot(); e.open();
		local n0 = #e.world.all;
		local id = e.c:Create("A", "warrior");
		for i = 1, 12 do e.c:Create("B" .. i, "warrior"); end
		e.c:SetView("library");
				e.ui:OpenEditor(id);
		for i = 1, 5 do pick(e, i); end
		e.c:SetCatalog("trinkets"); e.c:SelectSlot("rings", 2); e.c:ToggleAdvanced(); e.c:ToggleAdvanced();
		e.world.click(e.ui.ed.save);
		analyze(e, GOOD);
		e.world.clickLabel(T(e, "Import"), e.ui.views.import);
		e.c:PrepareExport(id, "saved"); e.c:SetView("export");
		e.world.click(e.ui.ex.back);
		eq(#e.world.all, n0, "frames/regions created after the first open");
		-- The import review uses one additional, pre-created overflow label; no widgets are created on refresh.
		ok(n0 <= 1750, "static texture/button budget including the read-only notes view and inspector matte: " .. n0);
	end);

	-- ------------------------------------------------------------------ layout lint at several sizes
	local function tour(e)
		local problems = {};
		local function lint(tag) for _, p in ipairs(e.lint()) do problems[#problems + 1] = tag .. ": " .. p; end end
		local long = string.rep("Nom tr\195\168s long \195\169\195\160 ", 8);
		local ids = {};
		for i = 1, 11 do ids[i] = e.c:Create(i == 1 and long or ("Build " .. i), i % 3 == 0 and "demonhunter" or "warrior"); end
		e.c:SetView("library");
		e.c:Select(ids[1]);
		lint("library");
		e.c:ShowTrash(true); lint("trash"); e.c:ShowTrash(false);
		e.ui:AskCreate(); lint("create dialog"); e.ui:ModalCancel();
		e.ui:AskDelete({ id = ids[1], name = long }); lint("delete dialog"); e.ui:ModalCancel();
		e.ui:OpenEditor(ids[1]);
		lint("editor empty");
		for p = 1, 6 do e.c:AddSpell(e.c:CatalogEntries()[p].key); end
		for p = 1, 3 do e.c:AddBanish(e.c:CatalogEntries()[6 + p].key); end
		for p = 1, 3 do e.c:ToggleBanishAfter(e.c:Editor().draft.phases[1].spells[p].key); end
		lint("editor spells with banish-after marks");
		for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
			e.c:SetCatalog(g);
			for s = 1, #e.c:Editor().draft.phases[1][g] do e.c:SelectSlot(g, s); e.c:SetSlot(g, s, e.c:CatalogEntries()[s].key); end
			lint("editor " .. g);
		end
		e.c:Inspect("spell", e.c:Editor().draft.phases[1].spells[1].key);
		lint("inspector");
		e.c:RevealPhases(); lint("editor phases");
		e.c:ToggleAdvanced();
		e.c:SetNotes(string.rep("Note \195\169\195\160 ", 300));
		e.c:SetLink("https://azreborn.com/planner/warrior");
		lint("editor advanced");
		e.c:ToggleAdvanced();
		e.ui:AskDirty(function() end); lint("dirty dialog"); e.ui:ModalCancel();
		e.c.state.message = nil;
		e.c:SetView("import");
		e.world.type(e.ui.im.box, CONFLICT);
		e.c:AnalyzeImport(CONFLICT);
		lint("import");
		e.c:AnalyzeImport("garbage");
		lint("import refused");
		e.c:PrepareExport(ids[1], "draft"); e.c:SetView("export");
		lint("export");
		e.c:AcceptLosses(); lint("export accepted");
		return problems;
	end

	for _, size in ipairs({ { 1365, 768, "1280x720 (16:9, UI units)" }, { 1920, 1080, "1920x1080" }, { 1024, 768, "1024x768" }, { 800, 600, "800x600" } }) do
		test("layout lint at " .. size[3] .. ", English and French", function()
			for _, loc in ipairs({ "enUS", "frFR" }) do
				local e = boot({ width = size[1], height = size[2], locale = loc }); e.open();
				local problems = tour(e);
				eq(problems, {}, size[3] .. " " .. loc);
			end
		end);
	end

	test("layout lint: initial editor has no clipped labels in any selectable language", function()
		for _, item in ipairs(H.loadAddon().Locale.LANGUAGES) do
			local loc = item.code == "auto" and "enUS" or item.code;
			local e = boot({ width = 1365, height = 768, locale = loc }); e.open();
			local id = e.c:Create("test", "warrior");
			e.ui:OpenEditor(id);
			eq(e.lint(), {}, "label layout in " .. loc);
		end
	end);

	test("layout lint Russian: translated labels remain inside controls", function()
		local e = boot({ width = 1365, height = 768, locale = "ruRU" }); e.open();
		eq(e.ns.Locale.lang, "ruRU");
		local problems = tour(e);
		eq(problems, {}, "Russian full client workflow, 1365x768");
	end);

	test("layout lint: another UI scale and a moved window", function()
		local e = boot({ width = 1365, height = 768, locale = "frFR" }); e.open();
		e.h():SetSetting("scale", 1.5);
		e.ui:ApplyScale();
		e.world.drag(e.root, 100, 60);
		eq(e.lint(), {}, "moved window");
		e.ui:ApplyScale();
		ok(e.root:GetScale() <= (768 - 24) / 540 + 1e-6);
		e.h():SetSetting("scale", 0.6);
		e.ui:ApplyScale();
		eq(e.lint(), {});
	end);

	test("a client without FontString:SetWordWrap still works", function()
		local e = boot({ noWordWrap = true }); e.open();
		e.c:Create("x", "warrior");
		ok(e.world.hasText("x"));
	end);

	-- ------------------------------------------------------------------ translations
	test("every string of the window has a French translation", function()
		local missing = {};
		local SAME = { ["Build"] = true, ["Page %d/%d"] = true, ["Info"] = true, ["Notes (%s)"] = true, ["Alternative %d"] = true, ["Alt. %d"] = true, ["Description"] = true };
		local ns = H.loadAddon();
		ns.Locale.SetLang("frFR");
		for _, f in ipairs({ "Controller.lua", "UI.lua", "Commands.lua", "Describe.lua" }) do
			local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f);
			for k in src:gmatch('L%("([^\n]-)"%)') do
				local key = k:gsub('\\"', '"');
				if ns.Locale.T(key) == key and not SAME[key] then missing[#missing + 1] = f .. ": " .. key; end
			end
			for k in src:gmatch('Locale%.T%("([^\n]-)"%)') do
				local key = k:gsub('\\"', '"');
				if ns.Locale.T(key) == key then missing[#missing + 1] = f .. ": " .. key; end
			end
		end
		for _, key in ipairs({ "%d statistic objective(s) kept (no editor yet)", "%d rank / unlimited target(s) kept (no editor yet)", "Extra data in %d phase(s) kept",
			"Extra build data kept: %s", "Limit reached", "Already in this list", "Read only", "The build is invalid" }) do
			if ns.Locale.T(key) == key then missing[#missing + 1] = "dynamic: " .. key; end
		end
		eq(missing, {});
	end);

	test("saved data holds identifiers and default labels, never translated text", function()
		local e = boot({ locale = "frFR" }); e.open();
		local id = e.c:Create("Plan", "warrior");
		e.ui:OpenEditor(id);
		pick(e, 2);
		e.world.click(e.ui.ed.save);
		local b = e.h():Get(id);
		eq(b.phases[1].label, "");
		eq(b.phases[1].spells[1].key, e.ns.catalog:SpellsOfClass("warrior")[2]);
		eq(b.class, "warrior");
		local text = H.serialize("X", e.G.RebornBuildPlannerDB);
		no(text:find("Tourbillon") or text:find("Guerrier") or text:find("D\195\169but"), "a translated label reached the saved data");
	end);
end
