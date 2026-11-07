require('setupkoenv')
local root=assert(os.getenv('KOHROMIUM_SOURCE'))
package.path=root..'/plugin/kohromium.koplugin/?.lua;'..package.path
local Engine=require('kohromium_engine')
local ffi=require('ffi');require('ffi/posix_h')
local frames=0
local e=Engine.new{executable=assert(os.getenv('KOHROMIUM_TEST_ENGINE')),profile=root..'/build/smoke-profile',logfile=root..'/build/smoke-engine.log',url='data:text/html,<title>KOhromium test</title><input autofocus>',width=800,height=600,on_event=function(kind,value)
 if kind=='frame' then frames=frames+1;assert(value:sub(1,8)=='\137PNG\r\n\26\n')end
 if kind=='error' then error(value)end
end}
local deadline=os.time()+30
while os.time()<deadline and frames==0 do assert(e:pump());e:capture();ffi.C.usleep(10000)end
assert(frames>0,'No screenshot')
local done=false
e:evaluate('document.title',function(value)assert(value=='KOhromium test');done=true end)
while os.time()<deadline and not done do assert(e:pump());ffi.C.usleep(10000)end
assert(done);e:stop()
for i=1,100 do if e.transport:reap(i>50) then break end;ffi.C.usleep(10000)end
print('PASS: KOReader Lua runtime -> local Chromium CDP -> title and PNG; clean shutdown')
