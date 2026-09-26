'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createRuntime } = require('../scripts/lua-runtime.cjs');

function withLibrary(callback, options) {
  const runtime = createRuntime(options);
  try { runtime.load(); runtime.run('__settle(90)'); callback(runtime); }
  finally { runtime.close(); }
}

function healthy(runtime) {
  const stats = runtime.stats();
  assert.deepEqual(Array.isArray(stats.errors) ? stats.errors : [], [], 'No unhandled task/render errors');
  assert.deepEqual(Array.isArray(stats.warnings) ? stats.warnings : [], [], 'No runtime failure warnings');
  assert.equal(runtime.run('return DxD.Alive'), true);
}

function clickText(runtime, text) {
  const item = runtime.snapshot().drawings.find((drawing) => drawing.kind === 'Text' && drawing.Text === text);
  assert.ok(item, `Visible label: ${text}`);
  runtime.run(`__click(${item.Position.X + 6}, ${item.Position.Y + 6}); __settle(25)`);
}

function pressKey(runtime, code) {
  runtime.run(`__key(${code},true); __step(); __key(${code},false); __settle(3)`);
}

test('pixel companions toggle independently, exchange positions, react and persist', () => withLibrary((runtime) => {
  const sprites = () => runtime.snapshot().drawings.filter(d => d.kind === 'Image' && d.Size.Y > 70 && d.Position.Y < 170);
  assert.equal(sprites().length, 2);
  const before = sprites().map(d => d.dataBase64);
  clickText(runtime, 'Artwork');
  clickText(runtime, 'Enabled');
  assert.equal(runtime.run('return DxD.RiasCompanion'), false);
  assert.equal(runtime.run('return DxD.AkenoCompanion'), true);
  assert.equal(sprites().length, 1);
  runtime.run('DxD:SetRiasCompanion(true); DxD:SetCompanionOrder("Akeno first"); __settle(30)');
  const after = sprites().sort((a,b) => a.Position.X-b.Position.X);
  assert.equal(after[0].dataBase64, before[1]);
  runtime.run(`assert(DxD:ReactCompanion("akeno")); assert(not DxD:ReactCompanion("unknown"));
    DxD:SetRiasCompanion(false); DxD:SaveSettings(); DxD:ResetSettings(); DxD:LoadSettings();
    assert(not DxD.RiasCompanion and DxD.AkenoCompanion and DxD.CompanionOrder == "Akeno first")`);
  healthy(runtime);
}));

test('artwork selections validate, persist and remain independent of palette', () => withLibrary((runtime) => {
  runtime.run(`assert(#DxD:GetArtworkOptions("akeno") == 6)
    assert(DxD:SetArtwork("akeno", "Blue sky")); assert(DxD:SetArtwork("rias", "Closing frame"))
    assert(not DxD:SetArtwork("rias", "Blue sky")); assert(not DxD:SetArtwork("invalid", "Anime loop"))
    DxD:SetTheme("Obsidian"); DxD:SetAnimatedMedia(false); assert(DxD:SaveSettings())
    DxD:ResetSettings(); assert(DxD:LoadSettings())
    assert(DxD.AkenoArtwork == "Blue sky" and DxD.RiasArtwork == "Closing frame")
    assert(DxD.Theme == "Obsidian" and not DxD.AnimatedMedia)`);
  healthy(runtime);
}));

test('anime loops advance while reduced motion and Low quality display a stable frame', () => withLibrary((runtime) => {
  const hero = () => runtime.snapshot().drawings.find(d => d.kind === 'Image' && d.Size.X > 200).dataBase64;
  const first = hero();
  runtime.run('__step(0.4)');
  assert.notEqual(hero(), first);
  for (const setting of ['DxD:SetReducedMotion(true)', 'DxD:SetReducedMotion(false); DxD:SetQuality("Low")', 'DxD:SetQuality("Balanced"); DxD:SetAnimatedMedia(false)']) {
    runtime.run(setting + '; __settle(8)');
    const still = hero();
    runtime.run('__step(0.6)');
    assert.equal(hero(), still);
  }
  healthy(runtime);
}));

test('mouse navigation, character selection, dropdown selection, and toggle work end to end', () => withLibrary((runtime) => {
  clickText(runtime, 'Meet the members');
  assert.equal(runtime.run('return DxD:GetDiagnostics().Selected'), 'Members');
  clickText(runtime, 'Select');
  assert.equal(runtime.run('return DxD.Character'), 'akeno');
  clickText(runtime, 'Settings');
  clickText(runtime, 'Himejima');
  clickText(runtime, 'Obsidian');
  assert.equal(runtime.run('return DxD.Theme'), 'Obsidian');
  clickText(runtime, 'Disabled');
  assert.equal(runtime.run('return DxD.ReducedMotion'), true);
  healthy(runtime);
}));

test('keyboard focus, activation, arrow adjustment, and escape operate actual controls', () => withLibrary((runtime) => {
  runtime.run(`
    local tab=DxD:AddTab('Keyboard')
    __keyboardSlider=tab:AddSlider({Title='Amount',Min=0,Max=10,Step=1,Default=5})
    tab:Select(); __settle(40)
  `);
  // Six nav controls, close button, then the slider. Tab through the visible interface.
  for (let i=0;i<8;i++) pressKey(runtime,9);
  pressKey(runtime,39);
  assert.equal(runtime.run('return __keyboardSlider:GetValue()'), 6);
  pressKey(runtime,37);
  assert.equal(runtime.run('return __keyboardSlider:GetValue()'), 5);
  pressKey(runtime,27);
  assert.equal(runtime.run('return DxD.Visible'), false);
  pressKey(runtime,161);
  assert.equal(runtime.run('return DxD.Visible'), true);
  healthy(runtime);
}));

test('key capture records a new hotkey and Escape cancels without modifying it', () => withLibrary((runtime) => {
  clickText(runtime, 'Settings');
  clickText(runtime, 'Right Shift');
  pressKey(runtime,0x70);
  assert.equal(runtime.run('return DxD.Keybind'),0x70);
  clickText(runtime,'F1');
  pressKey(runtime,27);
  assert.equal(runtime.run('return DxD.Keybind'),0x70);
  assert.equal(runtime.run('return DxD.Visible'),true);
  healthy(runtime);
}));

test('destructive confirmation can cancel and mouse-confirmed unload creates no drawings afterward', () => withLibrary((runtime) => {
  runtime.run(`DxD:Confirm({Title='Test unload',Content='Testing confirmation',Callback=function() DxD:Destroy() end}); __settle(30)`);
  clickText(runtime,'Cancel');
  assert.equal(runtime.run('return DxD.Alive'),true);
  runtime.run(`DxD:Confirm({Title='Test unload',Content='Testing confirmation',Callback=function() DxD:Destroy() end}); __settle(30)`);
  clickText(runtime,'Confirm');
  assert.equal(runtime.stats().live,0);
  assert.equal(runtime.stats().connections,0);
}));

test('low quality does not drop brief key presses between paint frames', () => withLibrary((runtime) => {
  runtime.run(`
    DxD:SetQuality('Low'); DxD:SetKeybind(0x2D)
    __key(0x2D,true); __step(1/240); assert(not DxD.Visible)
    __key(0x2D,false); __step(1/240)
    __key(0x2D,true); __step(1/240); assert(DxD.Visible)
    __key(0x2D,false); __settle(20)
  `);
  healthy(runtime);
}));

test('invalid custom icons are rejected before they reach the render loop', () => withLibrary((runtime) => {
  runtime.run(`
    assert(not pcall(function() DxD:AddTab({Icon={{1,2,'bad',4}}}) end))
    assert(not pcall(function() DxD.Home:AddButton({Icon={{1,2,math.huge,4}}}) end))
    local icon={{0,0,20,20}}
    local tab=DxD:AddTab({Title='Custom',Icon=icon})
    icon[1][1]='mutated'
    tab:Select(); __settle(30)
  `);
  healthy(runtime);
}));

test('boots a returned DxD instance with the preserved REM control API', () => {
  const runtime = createRuntime();
  try {
    const instance = runtime.load();
    assert.equal(instance && instance.Alive, true, 'Library chunk returns its live instance');
    runtime.run(`
      assert(DxD and DxD.Alive, "DxD must be a live global instance")
      assert(DxD.Home and DxD.Settings, "Built-in tabs must exist")
      for _, name in ipairs({"AddTab", "SetTheme", "SetKeybind", "SetAvatarData", "Notify", "Destroy", "SetCharacter", "SetQuality", "SetReducedMotion", "SetEffects", "SaveSettings", "LoadSettings"}) do
        assert(type(DxD[name]) == "function", "Missing API: " .. name)
      end
      local tab = DxD:AddTab("Compatibility")
      assert(tab:AddLabel("Information"))
      assert(tab:AddButton({Title="Action", Callback=function() end}))
      assert(tab:AddToggle({Title="Toggle"}))
      assert(tab:AddSlider({Title="Slider", Min=0, Max=10, Step=1}))
      assert(tab:AddDropdown({Title="Choice", Options={"One", "Two"}}))
      tab:Select()
      __settle(90)
    `);
    healthy(runtime);
    assert.ok(runtime.stats().visible > 0, 'Interface draws visible elements');
  } finally { runtime.close(); }
});

test('controls preserve values, snap sliders, suppress silent callbacks, and reject invalid dropdown choices', () => withLibrary((runtime) => {
  runtime.run(`
    local tab = DxD:AddTab({Title="Controls"})
    local changes = 0
    local toggle = tab:AddToggle({Title="Enabled", Default=false, Callback=function(value) changes=changes+1; assert(type(value)=="boolean") end})
    toggle:SetValue(true); assert(toggle:GetValue()==true and changes==1)
    toggle:SetValue(true); assert(changes==1, "Unchanged values must not fire callbacks")
    toggle:SetValue(false, true); assert(toggle:GetValue()==false and changes==1)
    local slider = tab:AddSlider({Title="Power", Min=10, Max=30, Step=2, Default=17})
    assert(slider:GetValue()==18)
    slider:SetValue(-500); assert(slider:GetValue()==10)
    slider:SetValue(500); assert(slider:GetValue()==30)
    local choice = tab:AddDropdown({Title="Mode", Options={"One", "Two"}, Default="Two"})
    assert(choice:GetValue()=="Two")
    assert(not pcall(function() choice:SetValue("Unknown") end))
    assert(choice:GetValue()=="Two", "Invalid values cannot mutate controls")
    tab:Select(); __settle(90); DxD.Home:Select(); __settle(30); tab:Select(); __settle(60)
    assert(slider:GetValue()==30 and choice:GetValue()=="Two" and toggle:GetValue()==false)
  `);
  healthy(runtime);
}));

test('invalid slider and keybind definitions fail before damaging the application', () => withLibrary((runtime) => {
  runtime.run(`
    local tab = DxD:AddTab("Validation")
    assert(not pcall(function() tab:AddSlider({Min=10, Max=0}) end))
    assert(not pcall(function() tab:AddSlider({Min=0, Max=10, Step=0}) end))
    assert(not pcall(function() tab:AddSlider({Min=0, Max=math.huge, Step=1}) end))
    assert(not pcall(function() tab:AddSlider({Min=0, Max=10, Step=0/0}) end))
    assert(not pcall(function() tab:AddDropdown({Options={}}) end))
    assert(not pcall(function() DxD:SetKeybind(27) end))
    assert(not pcall(function() DxD:SetKeybind(2.5) end))
    assert(not pcall(function() DxD:SetKeybind(999) end))
    DxD:SetKeybind(0x2D)
    assert(DxD.Keybind==0x2D)
    __settle(10)
  `);
  healthy(runtime);
}));

test('character, palette aliases, and graphics setters validate without corrupting state', () => withLibrary((runtime) => {
  runtime.run(`
    assert(DxD:SetCharacter("akeno") and DxD.Character=="akeno" and DxD.Theme=="Himejima")
    assert(not DxD:SetCharacter("missing") and DxD.Character=="akeno")
    assert(DxD:SetCharacter("rias") and DxD.Character=="rias" and DxD.Theme=="Gremory")
    for _, pair in ipairs({{"Purple","Himejima"},{"Green","Twilight"},{"Blue","Obsidian"},{"Black","Obsidian"}}) do
      assert(DxD:SetTheme(pair[1]) and DxD.Theme==pair[2])
    end
    assert(not DxD:SetTheme("unknown") and DxD.Theme=="Obsidian")
    for _, quality in ipairs({"Low","Balanced","High"}) do assert(DxD:SetQuality(quality) and DxD.Quality==quality); __settle(20) end
    assert(not DxD:SetQuality("Ultra") and DxD.Quality=="High")
    assert(DxD:SetReducedMotion(true) and DxD.ReducedMotion)
    assert(not DxD:SetReducedMotion("yes") and DxD.ReducedMotion)
    assert(DxD:SetEffects(false) and not DxD.Effects)
    assert(not DxD:SetEffects(1) and not DxD.Effects)
    assert(DxD:SetEffectStrength(.25) and DxD.EffectStrength==.25)
    assert(not DxD:SetEffectStrength(math.huge) and DxD.EffectStrength==.25)
    assert(not DxD:SetEffectStrength(-.1) and DxD.EffectStrength==.25)
    assert(DxD:SetOpacity(.85) and DxD.Opacity==.85)
    assert(not DxD:SetOpacity(.2) and DxD.Opacity==.85)
    __settle(20)
  `);
  healthy(runtime);
}));

test('settings round-trip preserves independently chosen character and palette', () => withLibrary((runtime) => {
  runtime.run(`
    assert(DxD:SetCharacter("akeno")); assert(DxD:SetTheme("Obsidian"))
    assert(DxD:SetQuality("Low")); assert(DxD:SetReducedMotion(true)); assert(DxD:SetEffects(false))
    assert(DxD:SetEffectStrength(.25)); assert(DxD:SetOpacity(.85)); DxD:SetKeybind(0x2D)
    assert(DxD:SetVolume("master",.2)); assert(DxD:SetVolume("music",.3)); assert(DxD:SetVolume("sfx",.4))
    assert(DxD:SaveSettings())
    assert(DxD:ResetSettings())
    assert(DxD:LoadSettings())
    assert(DxD.Character=="akeno" and DxD.Theme=="Obsidian", "Loading character cannot overwrite saved palette")
    assert(DxD.Quality=="Low" and DxD.ReducedMotion and not DxD.Effects)
    assert(DxD.EffectStrength==.25 and DxD.Opacity==.85 and DxD.Keybind==0x2D)
    assert(DxD.Audio.volume.master==.2 and DxD.Audio.volume.music==.3 and DxD.Audio.volume.sfx==.4)
    __settle(20)
  `);
  const saved = runtime.files.get('dxd-ui-v1.cfg');
  assert.ok(saved && saved.includes('version=1') && saved.includes('theme=Obsidian'));
  assert.ok(!saved.includes('loadstring'), 'Preferences are data, not executable Lua');
  healthy(runtime);
}));

test('configuration injection and invalid/duplicate fields are ignored as data', () => withLibrary((runtime) => {
  runtime.run('DxD:SetTheme("Obsidian"); DxD:SetQuality("Balanced"); DxD:SetOpacity(.9); DxD:SetKeybind(0x2D)');
  runtime.files.set('dxd-ui-v1.cfg', [
    'version=1',
    'theme=Gremory; _G.__injected=true',
    'character=missing',
    'quality=Low',
    'quality=High',
    'opacity=1e999',
    'keybind=27',
    'effects=false',
    'reducedMotion=true',
    'masterVolume=0/0',
    'os.execute("untrusted")',
    '__injected=true',
  ].join('\n'));
  runtime.run(`
    assert(DxD:LoadSettings())
    assert(__injected==nil)
    assert(DxD.Theme=="Obsidian" and DxD.Quality=="Balanced" and DxD.Opacity==.9 and DxD.Keybind==0x2D)
    assert(not DxD.Effects and DxD.ReducedMotion, "Valid independent data should still load")
    __settle(10)
  `);
  healthy(runtime);
}));

test('oversized, unsupported, and unavailable settings files fail safely', () => withLibrary((runtime) => {
  runtime.files.set('dxd-ui-v1.cfg', `version=1\n${'x'.repeat(8192)}`);
  runtime.run('assert(not DxD:LoadSettings()); assert(DxD.Character=="rias")');
  runtime.files.set('dxd-ui-v1.cfg', 'version=999\ncharacter=akeno');
  runtime.run('assert(not DxD:LoadSettings()); assert(DxD.Character=="rias")');
  runtime.run(`
    readfile=nil; writefile=nil
    assert(not DxD:LoadSettings()); assert(not DxD:SaveSettings())
    assert(DxD:SetCharacter("akeno"), "Session preferences still work without persistence")
    __settle(10)
  `);
  healthy(runtime);
}));

for (const failure of ['drawing', 'decoder']) {
  test(`failed image ${failure} falls back without repeated failures or app destruction`, () => {
    const runtime = createRuntime();
    try {
      if (failure === 'drawing') runtime.run('__runtime.failImages=true');
      else runtime.run('base64decode=function() error("Simulated missing decoder") end');
      runtime.load();
      runtime.run('__settle(90)');
      healthy(runtime);
      const before = runtime.stats().imageAttempts;
      runtime.run('__settle(180)');
      assert.equal(runtime.stats().imageAttempts, before, 'Unavailable image capability must not be retried every frame');
      const texts = runtime.snapshot().drawings.filter((drawing) => drawing.kind === 'Text').map((drawing) => drawing.Text);
      assert.ok(texts.some((text) => /Portrait unavailable/i.test(text)), 'Visible art fallback explains missing portrait');
      healthy(runtime);
    } finally { runtime.close(); }
  });
}

test('the assembled library performs no network requests for assets or identity', () => withLibrary((runtime) => {
  runtime.run('for _, tab in ipairs(DxD.Tabs) do tab:Select(); __settle(20) end; DxD:SetCharacter("akeno"); __settle(90)');
  assert.equal(runtime.stats().networkRequests, 0);
  healthy(runtime);
}));

test('audio adapter requires opt-in playback and cleans up on unload', () => withLibrary((runtime) => {
  runtime.run(`
    local calls={play=0,pause=0,destroy=0,volume=0}
    local adapter={
      play=function() calls.play=calls.play+1 end,
      pause=function() calls.pause=calls.pause+1 end,
      setVolume=function(_,channel,value) assert(channel=="master" or channel=="music" or channel=="sfx"); assert(value>=0 and value<=1); calls.volume=calls.volume+1 end,
      destroy=function() calls.destroy=calls.destroy+1 end,
    }
    assert(DxD:SetAudioAdapter(adapter))
    assert(calls.play==0 and not DxD.Audio.playing, "Attaching cannot autoplay")
    assert(DxD:PlayAudio() and DxD.Audio.playing and calls.play==1)
    assert(DxD:PauseAudio() and not DxD.Audio.playing)
    assert(DxD:SetVolume("master",0) and DxD.Audio.volume.master==0)
    assert(not DxD:SetVolume("master",2) and DxD.Audio.volume.master==0)
    DxD:Destroy()
    assert(calls.destroy==1 and calls.pause>=3)
  `);
  assert.equal(runtime.stats().live, 0);
  assert.equal(runtime.stats().connections, 0);
}));

test('reentrant audio unload cannot leave a destroyed UI playing or its adapter attached', () => withLibrary((runtime) => {
  runtime.run(`
    local ui=DxD
    local disposed=0
    assert(ui:SetAudioAdapter({
      play=function() ui:Destroy() end,
      pause=function() end,
      setVolume=function() end,
      destroy=function() disposed=disposed+1 end,
    }))
    ui:PlayAudio()
    assert(not ui.Alive and not ui.Audio.playing and not ui:HasAudioAdapter())
    assert(disposed==1, "Busy adapter must still dispose after reentrant unload")
  `);
  assert.equal(runtime.stats().live, 0);
}));

test('window hotkey uses edge detection and respects inactive application input', () => withLibrary((runtime) => {
  runtime.run(`
    DxD:SetKeybind(0x2D)
    assert(DxD.Visible)
    __key(0x2D,true); __step(); assert(not DxD.Visible)
    __settle(12); assert(not DxD.Visible, "Held key must not toggle repeatedly")
    __key(0x2D,false); __step(); __key(0x2D,true); __step(); assert(DxD.Visible)
    __key(0x2D,false); __step(); __setActive(false); __key(0x2D,true); __step(); assert(DxD.Visible)
    __key(0x2D,false); __setActive(true); __settle(20)
  `);
  healthy(runtime);
}));

test('strict Drawing property validation stays healthy across tabs and viewport changes', () => withLibrary((runtime) => {
  runtime.run(`
    for _, dimensions in ipairs({{1920,1080},{1440,900},{1024,768},{800,600},{390,844},{320,568}}) do
      __resize(dimensions[1], dimensions[2])
      for _, tab in ipairs(DxD.Tabs) do tab:Select(); __settle(20) end
      assert(DxD.Alive, "Render must survive viewport changes")
    end
    DxD.Visible=false; __settle(120); DxD.Visible=true; __settle(120)
  `);
  healthy(runtime);
}));

test('drawing allocation stabilizes after animation warmup', () => withLibrary((runtime) => {
  runtime.run('__settle(360)');
  const before = runtime.stats().created;
  runtime.run('__settle(360)');
  const after = runtime.stats().created;
  assert.equal(after, before, 'Stable UI frames must reuse pooled drawings');
  healthy(runtime);
}));

test('callback errors are contained and do not destroy the interface', () => withLibrary((runtime) => {
  runtime.run(`
    local tab=DxD:AddTab("Callback errors")
    local control=tab:AddToggle({Title="Throw", Callback=function() error("Expected consumer error") end})
    control:SetValue(true)
    __settle(20)
    assert(DxD.Alive)
  `);
  assert.deepEqual(Array.isArray(runtime.stats().errors) ? runtime.stats().errors : [], []);
  assert.equal(runtime.run('return DxD.Alive'), true);
}));

test('notifications stay bounded and expire without leaking new drawing objects', () => withLibrary((runtime) => {
  runtime.run(`for index=1,30 do DxD:Notify({Title="Notice "..index, Content="Bounded notification test", Type="success", Duration=1}) end; __settle(20)`);
  const first = runtime.stats().created;
  runtime.run(`__settle(180); for index=1,30 do DxD:Notify({Title="Again "..index, Content="Repeat", Duration=1}) end; __settle(20)`);
  const second = runtime.stats().created;
  assert.ok(second <= first + 10, 'Notification drawing allocation must remain bounded');
  runtime.run('__settle(180)');
  healthy(runtime);
}));

test('Destroy removes all drawings and disconnects render listeners idempotently', () => withLibrary((runtime) => {
  runtime.run('__oldUI=DxD; __oldUI:Destroy(); __oldUI:Destroy(); __settle(10); assert(not __oldUI.Alive)');
  const stats = runtime.stats();
  assert.equal(stats.live, 0);
  assert.equal(stats.connections, 0);
  assert.deepEqual(Array.isArray(stats.errors) ? stats.errors : [], []);
}));

test('reloading replaces the previous instance without leaving its drawings or render connection alive', () => withLibrary((runtime) => {
  runtime.run('__previous=DxD; __previousDrawings=#__runtime.drawings');
  runtime.load();
  runtime.run(`
    assert(DxD ~= __previous and not __previous.Alive)
    for index=1,__previousDrawings do assert(__runtime.drawings[index].removed, "Reload must retire old drawings") end
    __settle(90)
  `);
  healthy(runtime);
  assert.equal(runtime.stats().connections, 1, 'Only the current renderer should remain connected');
}));
