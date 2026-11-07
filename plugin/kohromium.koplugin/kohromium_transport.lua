-- Local CDP transport. A Unix socket is mapped to Chromium's fd 3/4;
-- there is no TCP debugging port. MSG_NOSIGNAL protects the reader on exit.
local ffi = require('ffi')
require('ffi/posix_h')
local bit = require('bit')
ffi.cdef[[int socketpair(int, int, int, int *); long send(int, const void *, unsigned long, int);]]
local C = ffi.C
local Transport = {}
Transport.__index = Transport
function Transport.start(executable, arguments, logfile)
    local fds = ffi.new('int[2]')
    assert(C.socketpair(1, bit.bor(1, 524288), 0, fds) == 0, 'Cannot create engine connection')
    local pid = C.fork()
    if pid < 0 then C.close(fds[0]); C.close(fds[1]); error('Cannot start engine') end
    if pid == 0 then
        C.close(fds[0]); C.setsid()
        local saved = C.fcntl(fds[1], 0, ffi.cast('int', 10)) -- F_DUPFD
        if saved < 0 then C._exit(126) end
        local log = C.open(logfile, bit.bor(1, 64, 1024), ffi.cast('int', 384))
        local null = C.open('/dev/null', 2)
        if log >= 0 then C.dup2(log, 2) end
        if null >= 0 then C.dup2(null, 0); C.dup2(null, 1) end
        C.dup2(saved, 3); C.dup2(saved, 4)
        for fd = 5, 1023 do C.close(fd) end
        local argv = ffi.new('char *[?]', #arguments + 2)
        local strings = {executable}
        for _, v in ipairs(arguments) do strings[#strings+1] = tostring(v) end
        for i, v in ipairs(strings) do argv[i-1] = ffi.cast('char *', v) end
        C.execvp(executable, argv)
        C._exit(127)
    end
    C.close(fds[1])
    C.fcntl(fds[0], 4, ffi.cast('int', bit.bor(C.fcntl(fds[0], 3), 2048)))
    return setmetatable({fd=tonumber(fds[0]), pid=tonumber(pid), pending='', received='', buffer=ffi.new('char[65536]')}, Transport)
end
function Transport:send(data)
    assert(self.fd, 'Browser connection is closed')
    assert(#self.pending + #data < 8*1024*1024, 'Engine write queue is full')
    self.pending = self.pending .. data
end
function Transport:pump(callback)
    if not self.fd then return false end
    if #self.pending > 0 then
        local n = tonumber(C.send(self.fd, self.pending, #self.pending, 16384))
        if n > 0 then self.pending = self.pending:sub(n+1)
        elseif n < 0 and ffi.errno() ~= 11 and ffi.errno() ~= 4 then return false end
    end
    -- Limit work per UI tick, so a busy renderer cannot monopolize KOReader.
    for _ = 1, 32 do
        local n = tonumber(C.read(self.fd, self.buffer, 65536))
        if n == 0 then return false end
        if n < 0 then return ffi.errno() == 11 or ffi.errno() == 4 end
        self.received = self.received .. ffi.string(self.buffer, n)
        if #self.received > 12*1024*1024 then error('Engine message exceeds memory limit') end
        while true do
            local pos = self.received:find('\0', 1, true)
            if not pos then break end
            local message = self.received:sub(1,pos-1)
            self.received = self.received:sub(pos+1)
            callback(message)
        end
    end
    return true
end
function Transport:stop()
    if self.fd then C.close(self.fd); self.fd=nil end
    if self.pid then C.kill(-self.pid, 15); C.kill(self.pid, 15) end
end
function Transport:reap(force)
    if not self.pid then return true end
    if force then C.kill(-self.pid, 9); C.kill(self.pid, 9) end
    local status = ffi.new('int[1]')
    if C.waitpid(self.pid,status,1) ~= 0 then self.pid=nil; return true end
    return false
end
return Transport
