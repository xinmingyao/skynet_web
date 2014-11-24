local skynet = require "skynet"
local express = {}
local _M = {}

--url_path,rule_path
function _M:use(...)
   skynet.send(self.web,"lua","use",...)
end

function _M:listen()
   local web = skynet.newservice("webd","master")
   assert(web)
   self.web = web
   skynet.call(web,"lua","start",self.port,self.config)
end
--web_root,static="*.html|*.css"
function express.app(port,config)
   local t = {port=port,config=config}
   return setmetatable(t,{__index=_M})
end

return express