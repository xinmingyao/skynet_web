local skynet = require "skynet"
local express = {}
local _M = {}

--url_path,rule_path
function _M:use(...)
   skynet.send(self.web,"lua","use",...)
end

function _M:listen()
   skynet.call(self.web,"lua","start",self.port,self.config)
end
--web_root,static="*.html|*.css"
function express.app(port,config)
   local t = {port=port,config=config}
   local web = skynet.newservice("webd","master")
   t.web = web
   return setmetatable(t,{__index=_M})
end

return express