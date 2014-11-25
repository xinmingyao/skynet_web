local lpeg = require "lpeg"
local R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local Cf = lpeg.Cf
local bnf ={}

local l = {}
lpeg.locale(l)


--rfc1630
function bnf.uri()
   local void = P""
   local punctuation = S("<>")
   local national = S("{}[]\\^~")
   local hex = l.xdigit
   local escape = P"%" * hex * hex
   local reserved = S("=;/#?:") + l.space
   local extra = S("!*'\"()")
   local safe = S("$-_@.&")
   local digit = l.digit
   local alpha = l.alpha
   local xalpha = alpha + digit + safe + extra + escape
   local xalphas = xalpha^1
   local xpalpha = xalpha + P"+"
   local ialpha = alpha * xalphas^-1
   local xpalphas = xpalpha^1
   local fragmentid = xalphas
   local search = xalphas^1
   local path = void 
      + xpalphas * (P"/" * xpalphas)^0
   local scheme = ialpha
   local uri = scheme * P":" * path  * search^0
   return uri
end

--rfc822
function bnf.email()
   local alpha = l.alpha
   local digit = l.digit
   local ctl = S("\t") --todo add ctl elements
   local cr = P"\r"
   local lf = P"\n"
   local space = l.space
   local htab = P"\t"
   local crlf = cr * lf
   local lwsp_char = space + htab
   local linear_white_space = (crlf^0 * lwsp_char)^1
   local specials = S("()<>$,;\\<.[]")
   local delimiters = specials + linear_white_space
   local atom = (l.alnum - space - ctl)^1
   local text = atom
   local qtext = atom - S('"\\') - cr
   local quoted_string = P'"' * qtext * P'"'
   local dtext = atom- S('[]\\') - cr
   local quoted_pair = P"\\" * alpha
   local domain_literal = P"[" * dtext + quoted_pair + P"]" 
   local word = atom + quoted_string
   local phrase = word^1
   local domain_ref = atom
   local sub_domain = domain_ref + domain_literal
   local domain = sub_domain * (P"." * sub_domain)^0
   local local_part = word * (P"." * word)^0
   local addr_spec = local_part * P"@" * domain

   local route = (P"@"*domain)^1 * P":"
   local route_addr = P"<" * route^-1 * addr_spec * P">"
   local mailbox = addr_spec
      +phrase * route_addr
   return mailbox
end

return bnf