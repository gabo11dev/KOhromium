local Device = require('device')
local UIManager = require('ui/uimanager')
local InputContainer = require('ui/widget/container/inputcontainer')
local FrameContainer = require('ui/widget/container/framecontainer')
local VerticalGroup = require('ui/widget/verticalgroup')
local ButtonTable = require('ui/widget/buttontable')
local TextWidget = require('ui/widget/textwidget')
local Font = require('ui/font')
local ImageWidget = require('ui/widget/imagewidget')
local RenderImage = require('ui/renderimage')
local Blitbuffer = require('ffi/blitbuffer')
local Geom = require('ui/geometry')
local GestureRange = require('ui/gesturerange')
local InputDialog = require('ui/widget/inputdialog')
local Menu = require('ui/widget/menu')
local InfoMessage = require('ui/widget/infomessage')
local Engine = require('kohromium_engine')
local Screen = Device.screen
local Browser = InputContainer:extend{ name='kohromium_browser', covers_fullscreen=true }
local Page = InputContainer:extend{}
function Page:getSize() return {w=self.width,h=self.height}end
function Page:init()
    self.dimen=Geom:new{x=0,y=0,w=self.width,h=self.height}
    self.ges_events={PageTap={GestureRange:new{ges='tap',range=function()return self.dimen end}},PageSwipe={GestureRange:new{ges='swipe',range=function()return self.dimen end}}}
    self.bitmap=Blitbuffer.new(self.width,self.height,Blitbuffer.TYPE_BB8);self.bitmap:fill(Blitbuffer.COLOR_WHITE)
    self.image=ImageWidget:new{image=self.bitmap,width=self.width,height=self.height}
end
function Page:paintTo(bb,x,y)
    self.dimen.x=x;self.dimen.y=y;self.image:paintTo(bb,x,y)
end
function Page:setFrame(png)
    local bitmap=RenderImage:renderImageData(png,#png,false,self.width,self.height)
    if not bitmap then return end
    self.image:free();self.image=ImageWidget:new{image=bitmap,width=self.width,height=self.height};self.bitmap=bitmap
end
function Page:free() if self.image then self.image:free();self.image=nil end end
function Page:onPageTap(_,ges)
    if self.owner.engine then self.owner.engine:tap(ges.pos.x-self.dimen.x,ges.pos.y-self.dimen.y)end
    return true
end
function Page:onPageSwipe(_,ges)
    if self.owner.engine then
        local d=math.floor(self.height*0.7)
        if ges.direction=='north' then self.owner.engine:scroll(0,d)
        elseif ges.direction=='south' then self.owner.engine:scroll(0,-d)
        elseif ges.direction=='west' then self.owner.engine:scroll(self.width*0.7,0)
        elseif ges.direction=='east' then self.owner.engine:scroll(-self.width*0.7,0)end
    end
    return true
end
function Browser:init()
    self.dimen=Geom:new{x=0,y=0,w=Screen:getWidth(),h=Screen:getHeight()}
    local w=self.dimen.w
    self.status=TextWidget:new{text='Starting KOhromium…',face=Font:getFace('cfont',16)}
    local function act(method,...) local args={...};return function()if self.engine then self.engine[method](self.engine,unpack(args))end end end
    self.toolbar=ButtonTable:new{width=w,buttons={{
        {text='Home',callback=function()self.engine:navigate(self.plugin:homeURL())end},
        {text='Back',callback=act('history',-1)},{text='Reload',callback=act('reload')},
        {text='Next',callback=act('history',1)},{text='Refresh',callback=function()UIManager:setDirty(self,'full')end},
        {text='Close',callback=function()self:close()end},
    }}}
    self.addressbar=ButtonTable:new{width=w,buttons={{
        {text='Address / search',width=math.floor(w*0.58),callback=function()self:address()end},
        {text='Keyboard',callback=function()self:editField()end},{text='More',callback=function()self:more()end},
    }}}
    self.page_height=math.max(100,self.dimen.h-self.toolbar:getSize().h-self.addressbar:getSize().h-self.status:getSize().h)
    self.page=Page:new{width=w,height=self.page_height,owner=self}
    self[1]=FrameContainer:new{padding=0,margin=0,bordersize=0,background=Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{align='left',self.toolbar,self.addressbar,self.status,self.page}}
    self.key_events={CloseBrowser={{'Back'},{'Esc'}}}
    self.tick_callback=function()self:tick()end
    self.capture_counter=0
end
function Browser:start()
    UIManager:preventStandby();self.standby_blocked=true
    local ok,engine=pcall(Engine.new,{
        executable=self.plugin:engineExecutable(),profile=self.plugin.path..'/state/profile',
        logfile=self.plugin.path..'/state/engine.log',home=self.plugin:homeURL(),url=self.plugin:homeURL(),
        width=self.dimen.w,height=self.page_height,scale=self.plugin.settings:readSetting('page_scale',1),
        user_agent=self.plugin.settings:readSetting('user_agent','Debian 13'),
        on_event=function(kind,value)self:event(kind,value)end,
    })
    if not ok then self:failed(engine);return end
    self.engine=engine;UIManager:scheduleIn(0.1,self.tick_callback)
end
function Browser:tick()
    if self.closed then return end
    local ok,alive=pcall(function()return self.engine:pump()end)
    if not ok or not alive then self:failed(ok and 'Chromium stopped. See state/engine.log.' or alive);return end
    self.capture_counter=self.capture_counter+1
    if self.capture_counter>=10 then self.capture_counter=0;self.engine:capture()end
    UIManager:scheduleIn(0.1,self.tick_callback)
end
function Browser:event(kind,value)
    if self.closed then return end
    if kind=='frame' then
        if value~=self.last_png then
            self.last_png=value;self.page:setFrame(value)
            if not self.dialog and not self.menu then UIManager:setDirty(self,'partial',self.page.dimen)end
        end
    elseif kind=='loading' then self.status:setText(value and 'Loading…' or 'KOhromium 156.0 — KOReader plugin');UIManager:setDirty(self,'ui')
    elseif kind=='url' then
        self.current_url=value
        local visits=self.plugin.settings:readSetting('history',{})
        if value~=self.plugin:homeURL() and value~='about:blank' and visits[1]~=value then
            table.insert(visits,1,value);while #visits>50 do table.remove(visits)end
            self.plugin.settings:saveSetting('history',visits)
        end
    elseif kind=='field' and not self.dialog then self:editField(value)
    elseif kind=='error' then self.status:setText('Browser error: '..tostring(value):sub(1,80));UIManager:setDirty(self,'ui')end
end
function Browser:prompt(title,value,callback,password)
    if self.dialog then return end
    local dialog
    local function submit(enter)
        local text=dialog:getInputText();self.dialog=nil;UIManager:close(dialog);callback(text,enter)
    end
    dialog=InputDialog:new{title=title,input=value or '',text_type=password and 'password' or nil,
        buttons={{
            {text='Cancel',callback=function()self.dialog=nil;UIManager:close(dialog)end},
            {text='Send',callback=function()submit(false)end},
            {text='Enter',is_enter_default=true,callback=function()submit(true)end},
        }}}
    local original_close=dialog.onCloseWidget
    dialog.onCloseWidget=function(d) if self.dialog==d then self.dialog=nil end;return original_close(d)end
    self.dialog=dialog;UIManager:show(dialog);dialog:onShowKeyboard()
end
function Browser:address()
    local current=self.current_url~=self.plugin:homeURL() and self.current_url or ''
    self:prompt('Address or search ('..self.plugin.settings:readSetting('search','WWW')..')',current,function(text)
        local url=Engine.resolve(text,self.plugin.settings:readSetting('search','WWW'))
        if url then self.engine:navigate(url)else UIManager:show(InfoMessage:new{text='Enter an address, or choose a search engine under More.'})end
    end)
end
function Browser:editField(field)
    self:prompt(field and 'Edit page field' or 'Send text to the focused page field',field and field.value or '',function(text,enter)self.engine:edit(text,enter)end,field and field.type=='password')
end
function Browser:openMenu(title,items)
    local menu
    for _,item in ipairs(items)do local callback=item.callback;if callback then item.callback=function()self.menu=nil;UIManager:close(menu);callback()end end end
    menu=Menu:new{title=title,width=math.floor(self.dimen.w*0.9),height=math.floor(self.dimen.h*0.85),item_table=items,
        close_callback=function()self.menu=nil;UIManager:close(menu)end}
    self.menu=menu;UIManager:show(menu)
end
function Browser:favorites()
    local entries=self.plugin.settings:readSetting('favorites',{})
    local items={{text='Save current page',callback=function()
        local url=self.current_url or self.plugin:homeURL()
        for _,entry in ipairs(entries)do if entry==url then return end end
        entries[#entries+1]=url;self.plugin.settings:saveSetting('favorites',entries);self.plugin.settings:flush()
    end}}
    for _,entry in ipairs(entries)do local url=entry;items[#items+1]={text=url,callback=function()self.engine:navigate(url)end}end
    self:openMenu('Favorites',items)
end
function Browser:more()
    self:openMenu('KOhromium',{
        {text='Favorites',callback=function()self:favorites()end},
        {text='History',callback=function()
            local items={};for _,entry in ipairs(self.plugin.settings:readSetting('history',{}))do local url=entry;items[#items+1]={text=url,callback=function()self.engine:navigate(url)end}end
            self:openMenu('History',items)
        end},
        {text='Search engine',callback=function()
            local items={};for _,v in ipairs({'WWW','Google','DuckDuckGo'})do local value=v;items[#items+1]={text=value,callback=function()self.plugin.settings:saveSetting('search',value)end}end
            self:openMenu('Search engine',items)
        end},
        {text='User agent',callback=function()
            local items={};for _,v in ipairs({'Debian 13','Android 11'})do local value=v;items[#items+1]={text=value,callback=function()self.plugin.settings:saveSetting('user_agent',value);self.engine:setUserAgent(value)end}end
            self:openMenu('User agent',items)
        end},
        {text='Page zoom +',callback=function()self:zoom(0.25)end},
        {text='Page zoom −',callback=function()self:zoom(-0.25)end},
        {text='Page arrows',callback=function()
            local items={};for _,v in ipairs({'ArrowUp','ArrowDown','ArrowLeft','ArrowRight'})do local key=v;items[#items+1]={text=key,callback=function()self.engine:key(key)end}end
            self:openMenu('Page arrows',items)
        end},
        {text='Use current page as home',callback=function()if self.current_url then self.plugin.settings:saveSetting('homepage',self.current_url)end end},
        {text='Restore default home',callback=function()self.plugin.settings:delSetting('homepage')end},
        {text='Delete cookies',callback=function()self.engine:command('Network.clearBrowserCookies');self.status:setText('Cookies deleted.');UIManager:setDirty(self,'ui')end},
        {text='Return to KOReader',callback=function()self:close()end},
    })
end
function Browser:zoom(delta)
    local scale=math.max(0.5,math.min(2.5,self.engine.scale+delta))
    self.plugin.settings:saveSetting('page_scale',scale);self.engine:resize(self.dimen.w,self.page_height,scale)
end
function Browser:failed(message)
    self:close();UIManager:show(InfoMessage:new{text='KOhromium could not continue.\n'..tostring(message):sub(1,300)})
end
function Browser:close()
    if self.closed then return end
    self.closed=true;UIManager:unschedule(self.tick_callback)
    if self.dialog then UIManager:close(self.dialog);self.dialog=nil end
    if self.menu then UIManager:close(self.menu);self.menu=nil end
    if self.engine then
        local transport=self.engine.transport;self.engine:stop()
        local attempts=0;local reap
        reap=function()attempts=attempts+1;if not transport:reap(attempts>20) then UIManager:scheduleIn(0.1,reap)end end
        reap()
    end
    if self.standby_blocked then UIManager:allowStandby();self.standby_blocked=false end
    self.plugin.settings:flush();self.plugin.browser=nil;UIManager:close(self);UIManager:setDirty('all','full')
end
function Browser:onCloseBrowser() self:close();return true end
function Browser:onSuspend() self:close()end
function Browser:onCloseWidget()
    if not self.closed then self:close();return end
    if not self.freed then self.freed=true;self:free()end
end
-- The first build closes on geometry changes rather than leaving stale touch coordinates.
function Browser:onSetRotationMode() self:close()end
function Browser:onScreenResize() self:close()end
return Browser
