local validate = {}
local lpeg = require "lpeg"
local R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local Cf = lpeg.Cf
local l = {}
lpeg.locale(l)
local space_c = function(pat)
   local sp = P" "^0
   return sp * C(pat) *sp 
end

local space_cg = function(pat,key)
   local sp = P" "^0
   return sp * Cg(C(pat),key) *sp 
end

local any = P(1)^1
local crlf = P"\r\n"
local tab =  P'\t'
local space = l.space
local alpha = l.alpha
local alnum = l.alnum
local digit = l.digit
local safe = alnum + S'-./:?#$&*;=@[]^_{|}+~"' + P"'"  
local email_safe = safe + space + tab
local pos_digit = R"19"
local integer = pos_digit * digit^0
local decimal_uchar = C(
   P'1' * digit * digit
      +P'2' * R('04') * digit
      +P'2' * P'5' * R('05')
      +(pos_digit * digit)
      +digit 
)
local byte = P(1) - S("\0\r\n") 
local byte_string =  byte^1--P"0x" * l.xdigit * l.xdigit
local text = safe^1
local messages = {
    required= "This field:%s is required.",
    remote= "Please fix this field.",
    email= "Please enter a valid email address.",
    url= "Please enter a valid URL.",
    date= "Please enter a valid date.",
    dateISO= "Please enter a valid date (ISO).",
    dateDE= "Bitte geben Sie ein g眉ltiges Datum ein.",
    number= "Please enter a valid number.",
    numberDE= "Bitte geben Sie eine Nummer ein.",
    digits= "Please enter only digits",
    creditcard= "Please enter a valid credit card number.",
    equalTo= "Please enter the same value again.",
    accept= "Please enter a value with a valid extension.",
    maxlength= "Please enter no more than %d characters.",
    minlength= "Please enter at least %d characters.",
    rangelength= "Please enter a value between %d and %d characters long.",
    range= "Please enter a value between %d and %d.",
    max= "Please enter a value less than or equal to %d.",
    min= "Please enter a value greater than or equal to %d."
}

local converts = {
   tonumber = function(v)
      return tonumber(v)
   end,
   tostring = function(v)
      return "" .. v
   end
}

local valid_funs = {
   required= 
      function(value)
	 if  value then
	    return true
	 end
      end,
   email= function(value)
   end,
   url= function(value)
   end,
   digits= function(value)
      local digits = l.digit ^ 1
      if digits:match(value) then
	 return true
      else
	 
      end
   end,
   option= function(value)
      return value
   end
}


local function parse_rule(str)
   local space = l.space ^ 0
   local key = l.alpha^1 
   local len = l.digit^1
   local range = P"[" * len * "," * len *"]"
   local value = len
      +range
   local pair = 
      key * P":" * value
   local rule = pair
      + key
   local sep = P(",") * space
   local rules =Ct((C(rule) * sep^0)^0)
   local r = Cg((P(1)-P"=")^1,"name") * P"=" * Cg(rules,"rules") * (P"/" * Cg(any,"convert"))^0
   local r1 = Ct(r)
   local t1 =  r1:match(str)
   
   if t1.rules then
   local k,v 
   for k,v in pairs(t1.rules) do
      local tt = string.find(v,"%[")
      if tt then
	 local r2 = C(key) * P":" * P"[" * C(len) * "," * C(len) *"]"
	 local k1,k2,k3 = r2:match(v)
	 
	 t1.rules[k] = {k1,tonumber(k2),tonumber(k3)}
      elseif v:find(":") then
	 local p2 = C(key) * P":" * C(value)
	 local k1,k2 = p2:match(v)
	 t1.rules[k] = {k1,tonumber(k2)}
      else
      end
   end
   end   
   return t1
end
function validate.valid_get(source,vs)
   local k,v
   local errs = {}
   local err = false
   local dst = {}
   for k,v in ipairs(vs) do
      local t1 = parse_rule(v)
      local name = t1.name
      local rules = t1.rules
      local k1,v1      
      for k1,v1 in ipairs(rules) do
	 if type(v1) == "string" then
	    local f = valid_funs[v1]
	    if f then	    
	       local value = source[name]
	       local ok = f(value)
	       if ok then
		  if t1.convert then
		     value = converts[t1.convert](value)
		  end
		  dst[name] = value
	       else
		  if v1 == "option" then break end
		  local str = string.format(messages[v1],name)
		  table.insert(errs,str)
		  err = true
	       end
	    end
	 end
      end
   end
   if err then
      return false,errs
   else
      return true,dst
   end
end


local test = ...
if test==true then
   local t = parse_rule("topic=required,digits,max:5,length:[1,2]/tonumber")
   assert(t.name=="topic")
   local k,v
   assert(t.rules[1] == "required")
   assert(t.rules[2] == "digits")
   assert(t.rules[3][1] == "max")
   assert(t.rules[3][2] == 5)
   assert(t.rules[4][1] == "length")
   assert(t.rules[4][2] == 1)
   assert(t.rules[4][3] == 2)
   assert(t.convert == "tonumber")
   
   local ok,t = validate.valid_get({topic="test",max=5},
				   {"topic=required",
				    "max=required/tonumber"
				   }
				   
   )
   assert(t.max == 5)
   assert(t.topic == "test")
   
   local ok,t = validate.valid_get({topic="test",max=5},
				   {"topic=required",
				    "max1=required/tonumber"
				   }
				   
   )
   assert(not ok)
   print(t[1])
end


return validate
