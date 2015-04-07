-- Copyright (C) Yichun Zhang (agentzh)
--modify yaoxinming

local byte = string.byte
local char = string.char
local sub = string.sub
local concat = table.concat
local str_char = string.char
local rand = math.random
local type = type
local debug = false --ngx.config.debug
local ngx_log = print --ngx.log
local ngx_DEBUG = print --ngx.DEBUG

-----for parser
local lpeg = require "lpeg"
local bnf = require "ws.bnf"
local R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local Cf = lpeg.Cf
local sdp ={}
local l = {}
lpeg.locale(l)

local space_c = function(pat)
   local sp = P" "^0
   return sp * C(pat) *sp 
--   return l.space^0 * pat * l.space^0
end

local space_cg = function(pat,key)
   local sp = P" "^0
   return sp * Cg(C(pat),key) *sp 
--   return l.space^0 * pat * l.space^0
end

function sdp.space(pat) 
   local sp = P" "^0
   return sp * pat *sp 
end

local any = P(1)^1
local crlf = P"\r\n"
local tab =  P'\t'
local space = P' ' --l.space
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
local byte1 = P(1) - S("\0\r\n") 
local byte_string =  byte1^1--P"0x" * l.xdigit * l.xdigit
local text = safe^1
local b1 = decimal_uchar - P'0' -- -P'127'
local b4 = decimal_uchar - P'0'
local ip4_address = b1 * P'.' * decimal_uchar * P'.' * decimal_uchar * P'.' * b4 
local unicast_address = ip4_address
local fqdn1 = alnum + S("-.")
local fqdn = fqdn1 * fqdn1 * fqdn1 * fqdn1
local addr =  unicast_address  + fqdn
local addrtype = P"IP4" +P"IP6"
local nettype = P"IN"
local phone = P"+" * pos_digit * (P" " + P"-" + digit)^1
local phone_number = phone 
   + (phone + P"(" + email_safe + P")")
   + (email_safe * P"<" * phone * P">")

local uri = bnf.uri()
local email = bnf.email()
local email_address = email 
   + (email * P"(" * email_safe^1 * P")")
   + (email_safe^1 * P"<" * email * P">")
local username = safe^1
local bandwidth = digit^1
local bwtype = alnum^1
local fixed_len_timer_unit = S("dhms")
local typed_time = digit^1 * fixed_len_timer_unit^-1
local repeat_interval = typed_time
local time = pos_digit * digit^-9
local start_time = time + P"0"
local stop_time = time + P"0"
local ttl = decimal_uchar
local multicast_address = decimal_uchar * P"." * decimal_uchar * P"." * decimal_uchar * P"." * decimal_uchar * P"/" * ttl * (P"/" * integer)^-1
local connection_address = multicast_address + addr
local sess_version = digit^1
local sess_id = digit^1
local att_value = byte_string
local att_field = (safe - P":") ^1
local attribute =(att_field * P":" * att_value) 
   + att_field
local port = digit^1
local proto = (alnum + S"/")^1
local fmt = alnum^1
local media = alnum^1

local proto_version = P"v=" * Cg(digit^1/tonumber,"v") * crlf

local req_line = Cg(Ct(space_c(text)^1) * crlf,"line")   
local head_value = byte_string
local head_field = (safe - P":") ^1
local header = Cg(space_c(head_field) * P":" * space_c(head_value)) * crlf
local headers = Cg(Cf(Ct("") *header^1,rawset),"headers")
local req = Ct(req_line * headers)

-------------

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end


local _M = new_tab(0, 5)

_M.new_tab = new_tab
_M._VERSION = '0.03'

local types = {
    [0x0] = "continuation",
    [0x1] = "text",
    [0x2] = "binary",
    [0x8] = "close",
    [0x9] = "ping",
    [0xa] = "pong",
}



function _M.parse(req_str)
   return req:match(req_str)
end

function _M.recv_frame(sock, max_payload_len, force_masking)
    local data, err = sock:readbytes(2)
    if not data then
        return nil, nil, "failed to receive the first 2 bytes: " .. err
    end

    local fst, snd = byte(data, 1, 2)

    local fin = (fst & 0x80) ~= 0
    -- print("fin: ", fin)

    if (fst & 0x70) ~= 0 then
        return nil, nil, "bad RSV1, RSV2, or RSV3 bits"
    end

    local opcode = (fst & 0x0f)
    -- print("opcode: ", tohex(opcode))

    if opcode >= 0x3 and opcode <= 0x7 then
        return nil, nil, "reserved non-control frames"
    end

    if opcode >= 0xb and opcode <= 0xf then
        return nil, nil, "reserved control frames"
    end

    local mask = (snd & 0x80) ~= 0

    if debug then
        ngx_log(ngx_DEBUG, "recv_frame: mask bit: ", mask and 1 or 0)
    end

    if force_masking and not mask then
        return nil, nil, "frame unmasked"
    end

    local payload_len = (snd & 0x7f)
    -- print("payload len: ", payload_len)

    if payload_len == 126 then
        local data, err = sock:readbytes(2)
        if not data then
            return nil, nil, "failed to receive the 2 byte payload length: "
                             .. (err or "unknown")
        end

        payload_len = ((byte(data, 1) << 8) | byte(data, 2))

    elseif payload_len == 127 then
        local data, err = sock:readbytes(8)
        if not data then
            return nil, nil, "failed to receive the 8 byte payload length: "
                             .. (err or "unknown")
        end

        if byte(data, 1) ~= 0
           or byte(data, 2) ~= 0
           or byte(data, 3) ~= 0
           or byte(data, 4) ~= 0
        then
            return nil, nil, "payload len too large"
        end

        local fifth = byte(data, 5)
        if (fifth & 0x80) ~= 0 then
            return nil, nil, "payload len too large"
        end

        payload_len = ((fifth<<24) |
                          (byte(data, 6) << 16)|
                          (byte(data, 7)<< 8)|
                          byte(data, 8))
    end

    if (opcode & 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, nil, "too long payload for control frame"
        end

        if not fin then
            return nil, nil, "fragmented control frame"
        end
    end

    -- print("payload len: ", payload_len, ", max payload len: ",
          -- max_payload_len)

    if payload_len > max_payload_len then
        return nil, nil, "exceeding max payload len"
    end

    local rest
    if mask then
        rest = payload_len + 4

    else
        rest = payload_len
    end
    -- print("rest: ", rest)

    local data
    if rest > 0 then
        data, err = sock:readbytes(rest)
        if not data then
            return nil, nil, "failed to read masking-len and payload: "
                             .. (err or "unknown")
        end
    else
        data = ""
    end

    -- print("received rest")

    if opcode == 0x8 then
        -- being a close frame
        if payload_len > 0 then
            if payload_len < 2 then
                return nil, nil, "close frame with a body must carry a 2-byte"
                                 .. " status code"
            end

            local msg, code
            if mask then
                local fst = (byte(data, 4 + 1) ~ byte(data, 1))
                local snd = (byte(data, 4 + 2) ~ byte(data, 2))
                code = ((fst << 8) | snd)

                if payload_len > 2 then
                    -- TODO string.buffer optimizations
                    local bytes = new_tab(payload_len - 2, 0)
                    for i = 3, payload_len do
                        bytes[i - 2] = str_char((byte(data, 4 + i) |
                                                     byte(data,
                                                          (i - 1) % 4 + 1)))
                    end
                    msg = concat(bytes)

                else
                    msg = ""
                end

            else
                local fst = byte(data, 1)
                local snd = byte(data, 2)
                code = ((fst << 8) | snd)

                -- print("parsing unmasked close frame payload: ", payload_len)

                if payload_len > 2 then
                    msg = sub(data, 3)

                else
                    msg = ""
                end
            end

            return msg, "close", code
        end

        return "", "close", nil
    end

    local msg
    if mask then
        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char((byte(data, 4 + i) ~
                                     byte(data, (i - 1) % 4 + 1)))
        end
        msg = concat(bytes)

    else
        msg = data
    end

    return msg, types[opcode], not fin and "again" or nil
end


local function build_frame(fin, opcode, payload_len, payload, masking)
    -- XXX optimize this when we have string.buffer in LuaJIT 2.1
    local fst
    if fin then
        fst = (0x80 | opcode)
    else
        fst = opcode
    end

    local snd, extra_len_bytes
    if payload_len <= 125 then
        snd = payload_len
        extra_len_bytes = ""

    elseif payload_len <= 65535 then
        snd = 126
        extra_len_bytes = char(((payload_len >> 8) & 0xff),
	   (payload_len & 0xff))

    else
        if (payload_len & 0x7fffffff) < payload_len then
            return nil, "payload too big"
        end

        snd = 127
        -- XXX we only support 31-bit length here
        extra_len_bytes = char(0, 0, 0, 0, ((payload_len >> 24) & 0xff),
                               ((payload_len >> 16) & 0xff),
                               ((payload_len >> 8)& 0xff),
                               (payload_len & 0xff))
    end

    local masking_key
    if masking then
        -- set the mask bit
        snd = (snd | 0x80)
        local key = rand(0xffffffff)
        masking_key = char(((key >> 24) & 0xff),
	   ((key >> 16) & 0xff),
	   ((key >> 8) & 0xff),
	   (key & 0xff))

        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char((byte(payload, i) ~
                                     byte(masking_key, (i - 1) % 4 + 1)))
        end
        payload = concat(bytes)

    else
        masking_key = ""
    end

    return char(fst, snd) .. extra_len_bytes .. masking_key .. payload
end
_M.build_frame = build_frame


function _M.send_frame(sock, fin, opcode, payload, max_payload_len, masking)
    -- ngx.log(ngx.WARN, ngx.var.uri, ": masking: ", masking)

    if not payload then
        payload = ""

    elseif type(payload) ~= "string" then
        payload = tostring(payload)
    end

    local payload_len = #payload

    if payload_len > max_payload_len then
        return nil, "payload too big"
    end

    if (opcode & 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, "too much payload for control frame"
        end
        if not fin then
            return nil, "fragmented control frame"
        end
    end

    local frame, err = build_frame(fin, opcode, payload_len, payload,
                                   masking)
    if not frame then
        return nil, "failed to build frame: " .. err
    end
    sock:write(frame)
end

function _M.parse_test()
   local path = "test"
   host = "192.168.203.157"
   port = 8080
   key = "test_key"
   local req = "GET " .. path .. " HTTP/1.1\r\nUpgrade: websocket\r\nHost: "
      .. host .. ":" .. port
      .. "\r\nSec-WebSocket-Key: " .. key
      .. "\r\nSec-WebSocket-Version: 13"
      .. "\r\nConnection: Upgrade\r\n\r\n"
   local p = _M.parse(req)
   print(req)
   print(text:match("HTTP/1.1"))
   print(req_line:match(req))
   print(p.headers["Host"])
end

return _M
