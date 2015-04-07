local helper = {}
local sock_M = {}
local socket = require "socket"

function sock_M:readbytes(sz)
   local id = self.id
   return socket.read(id,sz)
end

function sock_M:readline(sep)
   local id = self.id
   return socket.readline(id,sep)
end

function sock_M:write(...)
   local id = self.id
   return socket.write(id,...)
end

function sock_M:id(...)
   return self.id
end
function sock_M:close()
   socket.close(self.id)
end
function helper.open(...)
   return socket.open(...)
end
function helper.new_sock(id)
   local t = {id=id}
   return setmetatable(t,{__index=sock_M})
end

return helper