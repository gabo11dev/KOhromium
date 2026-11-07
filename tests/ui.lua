io.stdout:setvbuf('line')
io.stderr:setvbuf('line')
require('setupkoenv')
local root=assert(os.getenv('KOHROMIUM_SOURCE'))
package.path=root..'/build/test-plugin/?.lua;'..package.path
G_defaults=require('luadefaults'):open()
G_reader_settings=require('luasettings'):open(root..'/build/reader-settings.lua')
local Device=require('device')
Device.hasKeyboard=function()return false end
G_reader_settings:saveSetting('virtual_keyboard_enabled',true)
G_reader_settings:saveSetting('keyboard_layout','es')
G_reader_settings:saveSetting('keyboard_layout_default','es')
require('document/canvascontext'):init(Device)
require('ui/bidi').setup()
local UIManager=require('ui/uimanager')
local Frame=require('ui/widget/container/framecontainer')
local Text=require('ui/widget/textwidget')
local Font=require('ui/font')
local BB=require('ffi/blitbuffer')
local reader=Frame:new{background=BB.COLOR_WHITE,padding=0,Text:new{text='KOReader — return target',face=Font:getFace('cfont',24)}}
UIManager:show(reader)
local E=require('kohromium_engine');local receive=E.receive;E.receive=function(self,raw)local d=require('rapidjson').decode(raw);print('CDP',d.id or '',d.method or '',#raw,self.generation);return receive(self,raw)end
local Plugin=require('main')
local menu_items
local plugin=Plugin:new{path=root..'/build/test-plugin',ui={menu={registerToMainMenu=function(_,p)menu_items={};p:addToMainMenu(menu_items)end}}}
assert(menu_items.kohromium)
plugin:openBrowser()
local browser=assert(plugin.browser)
print('BROWSER STARTED', browser.engine and browser.engine.ready)
local phase=0
local start=os.time()
local result=false
local function picture(name)UIManager:forceRePaint();Device.screen.bb:writePNG(root..'/docs/'..name..'.png')end
local step
step=function()
    print('PHASE',phase,browser.engine and browser.engine.ready,browser.last_png and #browser.last_png,browser.engine and browser.engine.capture_pending,browser.capture_counter)
    assert(os.time()-start<80,'UI integration timed out')
    if not browser.engine or not browser.last_png then UIManager:scheduleIn(0.3,step);return end
    if phase==0 then
        picture('home');browser:address();phase=1
    elseif phase==1 then
        assert(browser.dialog);assert(browser.dialog._input_widget:isKeyboardVisible());assert(UIManager:getTopmostVisibleWidget()==browser.dialog or UIManager:getTopmostVisibleWidget()==browser.dialog._input_widget.keyboard);picture('keyboard');UIManager:close(browser.dialog);assert(not browser.dialog)
        browser:more();phase=2
    elseif phase==2 then
        assert(browser.menu);assert(UIManager:getTopmostVisibleWidget()==browser.menu);picture('menu');UIManager:close(browser.menu);browser.menu=nil
        browser.engine:navigate('file://'..root..'/build/input.html');phase=3
    elseif phase==3 then
        if browser.engine.loading or browser.current_url~='file://'..root..'/build/input.html' then UIManager:scheduleIn(0.3,step);return end
        browser.page:onPageTap(nil,{pos={x=browser.page.dimen.x+70,y=browser.page.dimen.y+70}});phase=4
    elseif phase==4 then
        assert(browser.dialog,'Native keyboard did not open after field tap')
        picture('page-field');assert(browser.dialog._input_widget:isKeyboardVisible());browser.dialog._input_widget:addChars('ñ KOReader');browser.dialog.buttons[1][3].callback();phase=5
    elseif phase==5 then
        browser.engine:evaluate("JSON.stringify({value:document.querySelector('input').value,enters:window.enters})",function(value)
            local v=require('rapidjson').decode(value);assert(v.value=='ñ KOReader');assert(v.enters==1);result=true
        end);phase=6
    elseif phase==6 then
        if not result then UIManager:scheduleIn(0.2,step);return end
        browser:zoom(0.25);phase=7
    elseif phase==7 then
        assert(browser.engine.scale==1.25);picture('page');local transport=browser.engine.transport
        browser:close();assert(plugin.browser==nil);assert(browser.closed and browser.freed)
        assert(UIManager:getTopmostVisibleWidget()==reader,'Did not return to KOReader widget')
        UIManager:scheduleIn(1,function()picture('returned');assert(transport:reap(true));UIManager:close(reader);UIManager:quit();print('PASS: native KOReader UI, menus, keyboard, field tap/edit/Enter, zoom, frame display, shutdown and return')end)
        return
    end
    UIManager:scheduleIn(1,step)
end
UIManager:scheduleIn(1,step)
UIManager:run()
assert(result)
