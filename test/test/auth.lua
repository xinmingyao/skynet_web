local validate = require "web.validate"
local table = require "table"
function rep.tocken(req)
   if req.query.tocken then
      return 200 
   else
      return 401,"Unauth"
   end
end
