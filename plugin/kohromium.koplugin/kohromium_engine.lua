local json = require('rapidjson')
local mime = require('mime')
local Transport = require('kohromium_transport')
local Engine = {}; Engine.__index=Engine
function Engine.resolve(text, search)
    text = text:match('^%s*(.-)%s*$')
    if text == '' then return nil end
    if text:match('^[%a][%w+.-]*:') then return text end
    if search == 'Google' or search == 'DuckDuckGo' then
        local encoded=text:gsub('([^%w%-._~])',function(c)return string.format('%%%02X',c:byte())end)
        return (search=='Google' and 'https://www.google.com/search?q=' or 'https://duckduckgo.com/?q=')..encoded
    end
    if text:find('%s') then return nil end
    return 'https://'..text
end
function Engine.new(options)
    local self=setmetatable({options=options,callbacks={},id=0,generation=0,ready=false,url=options.url,loading=true,width=options.width,height=options.height,scale=options.scale or 1},Engine)
    local args={'--remote-debugging-pipe','--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--no-first-run','--disable-background-networking','--disable-sync','--no-default-browser-check','--disable-breakpad','--user-data-dir='..options.profile,'--window-size='..options.width..','..options.height,'about:blank'}
    if options.extra_args then for _,v in ipairs(options.extra_args)do args[#args+1]=v end end
    self.transport=Transport.start(options.executable,args,options.logfile)
    self:command('Target.createTarget',{url='about:blank'},function(r)
        assert(r.targetId,'Cannot create browser target')
        self:command('Target.attachToTarget',{targetId=r.targetId,flatten=true},function(a)
            assert(a.sessionId,'Cannot attach browser target');self.session=a.sessionId
            self:command('Page.enable');self:command('Runtime.enable')
            self:command('Runtime.addBinding',{name='kohromiumNavigate'})
            self:setUserAgent(options.user_agent or 'Debian 13',function()
                self.ready=true;self:resize(self.width,self.height,self.scale,function()self:navigate(options.url)end)
            end)
        end,true)
    end,true)
    return self
end
function Engine:command(method,params,callback,browser)
    if self.closed then return end
    self.id=self.id+1
    local message={id=self.id,method=method,params=params or {}}
    if not browser then message.sessionId=self.session end
    if callback then self.callbacks[self.id]=callback end
    self.transport:send(json.encode(message)..'\0')
    return self.id
end
function Engine:notify(kind,value) if self.options.on_event then self.options.on_event(kind,value)end end
function Engine:receive(raw)
    local d=json.decode(raw);if not d then return end
    if d.id then
        local callback=self.callbacks[d.id];self.callbacks[d.id]=nil
        if d.error then self:notify('error',d.error.message);if callback then callback({},d.error)end
        elseif callback then callback(d.result or {})end
        return
    end
    local p=d.params or {}
    if d.method=='Page.frameStartedLoading' and (not self.frame_id or p.frameId==self.frame_id) then self.loading=true;self.loading_since=os.time();self:notify('loading',true)
    elseif d.method=='Page.loadEventFired' then self.loading=false;self:notify('loading',false)
    elseif d.method=='Page.frameNavigated' and p.frame and not p.frame.parentId then
        self.frame_id=p.frame.id;self.generation=self.generation+1;self.url=p.frame.url;self:notify('url',self.url)
    elseif d.method=='Runtime.bindingCalled' and p.name=='kohromiumNavigate' and self.url==self.options.home then
        local url=Engine.resolve(p.payload,'WWW');if url then self:navigate(url)end
    end
end
function Engine:pump() return self.transport:pump(function(raw)self:receive(raw)end) end
function Engine:navigate(url)
    self.generation=self.generation+1;self.loading=true;self.loading_since=os.time();self.url=url
    if self.capture_id then self.callbacks[self.capture_id]=nil end;self.capture_pending=false
    self:notify('loading',true);self:command('Page.navigate',{url=url})
end
function Engine:resize(w,h,scale,callback)
    self.width=w;self.height=h;self.scale=scale;self.generation=self.generation+1
    local cw,ch=math.max(1,math.floor(w/scale)),math.max(1,math.floor(h/scale))
    self:command('Emulation.setDeviceMetricsOverride',{width=cw,height=ch,deviceScaleFactor=scale,mobile=false},function()
        self:command('Emulation.setVisibleSize',{width=cw,height=ch},callback)
    end)
end
function Engine:capture()
    if not self.ready or self.closed or (self.loading and os.time()-(self.loading_since or os.time())<3) then return end
    if self.capture_pending and os.time()-(self.capture_started or 0)>5 then self.callbacks[self.capture_id]=nil;self.capture_pending=false end
    if self.capture_pending then return end
    self.capture_pending=true;self.capture_started=os.time();local generation=self.generation
    self.capture_id=self:command('Page.captureScreenshot',{format='png',fromSurface=true,captureBeyondViewport=false},function(r)
        self.capture_pending=false
        if generation==self.generation and r.data then self:notify('frame',mime.unb64(r.data))end
    end)
end
function Engine:evaluate(expression,callback)
    self:command('Runtime.evaluate',{expression=expression,returnByValue=true},function(r,e)
        if callback then callback(r.result and r.result.value,e or r.exceptionDetails)end
    end)
end
function Engine:tap(x,y)
    x=x/self.scale;y=y/self.scale
    self:command('Input.dispatchMouseEvent',{type='mousePressed',x=x,y=y,button='left',clickCount=1})
    self:command('Input.dispatchMouseEvent',{type='mouseReleased',x=x,y=y,button='left',clickCount=1},function()
        self:evaluate([[(()=>{const e=document.activeElement;if(!e||e.disabled||e.readOnly)return '';if(!(e.tagName==='TEXTAREA'||e.tagName==='INPUT'&&!/^(button|submit|reset|checkbox|radio|range|color|file|hidden)$/.test(e.type)))return '';return JSON.stringify({value:e.value,type:e.type||'text'});})()]],function(value)
            if value and value~='' then self:notify('field',json.decode(value))end
        end)
    end)
end
function Engine:edit(text,enter)
    self:evaluate("(()=>{let e=document.activeElement;if(e&&e.select){e.focus();e.select();}return true})()",function()
        self:command('Input.insertText',{text=text},function()if enter then self:key('Enter')end end)
    end)
end
function Engine:key(key)
    local codes={Enter=13,ArrowLeft=37,ArrowUp=38,ArrowRight=39,ArrowDown=40,Backspace=8}
    local p={type='keyDown',key=key,code=key,windowsVirtualKeyCode=codes[key] or 0,nativeVirtualKeyCode=codes[key] or 0}
    if key=='Enter' then p.text='\r';p.unmodifiedText='\r'end
    self:command('Input.dispatchKeyEvent',p);p.type='keyUp';p.text=nil;p.unmodifiedText=nil;self:command('Input.dispatchKeyEvent',p)
end
function Engine:scroll(dx,dy)
    self:command('Input.dispatchMouseEvent',{type='mouseWheel',x=self.width/self.scale/2,y=self.height/self.scale/2,deltaX=dx/self.scale,deltaY=dy/self.scale})
end
function Engine:history(delta)
    self:command('Page.getNavigationHistory',{},function(r)
        local entry=r.entries and r.entries[(r.currentIndex or 0)+delta+1]
        if entry then self:command('Page.navigateToHistoryEntry',{entryId=entry.id})end
    end)
end
function Engine:reload() self:command('Page.reload',{ignoreCache=false})end
function Engine:setUserAgent(name,callback)
    local mobile=name=='Android 11'
    self:command('Emulation.setUserAgentOverride',{userAgent=mobile and 'Mozilla/5.0 (Linux; Android 11; Kindle PW4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Mobile Safari/537.36' or 'Mozilla/5.0 (X11; Linux armv7l) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36',platform=mobile and 'Linux armv7l' or 'Linux',userAgentMetadata={brands={{brand='Chromium',version='156'}},fullVersionList={{brand='Chromium',version='156.0.8078.73'}},platform=mobile and 'Android' or 'Linux',platformVersion=mobile and '11.0.0' or '13.0.0',architecture='arm',model=mobile and 'Kindle PW4' or '',mobile=mobile,bitness='32'}},callback)
end
function Engine:stop() self.closed=true;self.callbacks={};self.transport:stop()end
return Engine
