local WidgetContainer = require('ui/widget/container/widgetcontainer')
local UIManager = require('ui/uimanager')
local InfoMessage = require('ui/widget/infomessage')
local LuaSettings = require('luasettings')
local ffiUtil = require('ffi/util')
local lfs = require('libs/libkoreader-lfs')
local Device = require('device')
local KOhromium = WidgetContainer:extend{name='kohromium',is_doc_only=false}
function KOhromium:init()
    self.path=assert(ffiUtil.realpath(self.path))
    lfs.mkdir(self.path..'/state');lfs.mkdir(self.path..'/state/profile')
    self.settings=LuaSettings:open(self.path..'/state/settings.lua')
    self.ui.menu:registerToMainMenu(self)
end
function KOhromium:defaultHome()return 'file://'..self.path..'/assets/home.html'end
function KOhromium:homeURL()return self.settings:readSetting('homepage',self:defaultHome())end
function KOhromium:engineExecutable()
    -- Test override is intentionally limited to KOReader's desktop platform.
    if not Device:isKindle() and os.getenv('KOHROMIUM_TEST_ENGINE') then return os.getenv('KOHROMIUM_TEST_ENGINE')end
    return self.path..'/engine.sh'
end
function KOhromium:openBrowser()
    if self.browser then return end
    if not Device:isKindle() and not os.getenv('KOHROMIUM_TEST_ENGINE') then
        UIManager:show(InfoMessage:new{text='This package targets Kindle PW4 hard-float firmware. Other KOReader platforms are not included.'});return
    end
    if Device:isKindle() and not ffiUtil.isExecutable('/lib/ld-linux-armhf.so.3') then
        UIManager:show(InfoMessage:new{text='KOhromium 156.0 HF requires hard-float Kindle firmware. This is not a PW3/SF build.'});return
    end
    local Browser=require('kohromium_browser')
    self.browser=Browser:new{plugin=self};UIManager:show(self.browser);self.browser:start()
end
function KOhromium:addToMainMenu(menu_items)
    menu_items.kohromium={text='KOhromium',sorting_hint='more_tools',sub_item_table={
        {text='Open browser',callback=function()self:openBrowser()end},
        {text='About KOhromium',callback=function()UIManager:show(InfoMessage:new{text='KOhromium 156.0 HF Alpha 1\nChromium inside KOReader.\nBuilt with AI assistance.\nNo physical Kindle test of this plugin yet.\nChromium runs without its sandbox.'})end},
    }}
end
function KOhromium:stopPlugin()if self.browser then self.browser:close()end;self.settings:flush()end
function KOhromium:onClose()self:stopPlugin()end
return KOhromium
