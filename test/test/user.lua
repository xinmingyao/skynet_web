local validate = require "web.validate"
local table = require "table"
function rep.index(req)
   local ok,t = validate.valid_get(req.query,
				   {"id=required",
				    "max=required/tonumber"
				   }
				   
   )
   print(ok,t[1])
   return 200,"echo",{}
end
