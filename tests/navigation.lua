require('setupkoenv')
local root=assert(os.getenv('KOHROMIUM_SOURCE'))
package.path=root..'/plugin/kohromium.koplugin/?.lua;'..package.path
local Engine=require('kohromium_engine')
local Transport=require('kohromium_transport')
local ffi=require('ffi');require('ffi/posix_h')
local first='data:text/html,<title>First</title><body style="height:4000px"><input><script>window.keys=[];onkeydown=e=>keys.push(e.key)</script>'
local second='data:text/html,<title>Second</title>'
local e=Engine.new{executable=assert(os.getenv('KOHROMIUM_TEST_ENGINE')),profile=root..'/build/navigation-profile',logfile=root..'/build/navigation.log',url=first,width=800,height=600}
local function untilTrue(check)
 local deadline=os.time()+20
 repeat assert(e:pump(),'Engine disconnected');if check()then return end;ffi.C.usleep(10000)until os.time()>deadline
 error('Navigation test timed out')
end
local function value(expression)
 local done,result=false,nil
 e:evaluate(expression,function(v,err)assert(not err);result=v;done=true end)
 untilTrue(function()return done end);return result
end
local function title(expected)
 untilTrue(function()return e.ready and not e.loading end)
 assert(value('document.title')==expected)
end
title('First')
e:navigate(second);title('Second')
e:history(-1);untilTrue(function()return e.url==first and not e.loading end);title('First')
e:history(1);untilTrue(function()return e.url==second and not e.loading end);title('Second')
value('window.reloadProbe=1');e:reload()
untilTrue(function()return value('window.reloadProbe===undefined')end)
e:setUserAgent('Android 11');assert(value('navigator.userAgent'):find('Android 11',1,true))
e:navigate(first);title('First');e:key('ArrowDown')
untilTrue(function()return value('keys.includes("ArrowDown")')end)
e:scroll(0,500);untilTrue(function()return value('scrollY>0')end)
e:stop();for i=1,100 do if e.transport:reap(i>50)then break end;ffi.C.usleep(10000)end
assert(not e.transport.pid,'Engine was not reaped')
local dead=Transport.start('/bin/true',{},root..'/build/dead-engine.log')
ffi.C.usleep(100000);dead:send('{}\0');assert(not dead:pump(function()end),'Closed pipe should disconnect without SIGPIPE');dead:stop();dead:reap(true)
print('PASS: back, forward, reload, Android user agent, arrow key, scroll, shutdown and broken pipe')
