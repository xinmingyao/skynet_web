local skynet = require "skynet"
local snax = require "snax"
local socket = require "socket"
local fid,addr = ...
local ws_server = require "ws.ws_server"
local ws_client = require "ws.ws_client"
local handle = function(...)
   print(...)
end
local server
local  handle = {
   text = function(msg)
      print("receive:",msg)
      server:send_text(msg)
   end  
}

function test_client()
   local ws = ws_client.new()
   ws:connect("ws://127.0.0.1:6005/t")
   ws:send_text("ping1")
   print("111:",ws:recv_frame())
   ws:send_text("ping2")
   print("222:",ws:recv_frame())
   ws:send_text("ping3")
end


if fid then
   skynet.start(function()
		   socket.start(tonumber(fid))
		   server = ws_server.new(tonumber(fid),handle)
		   assert(server,"ws start error")
   end)
   
else
   skynet.start(function()		
		   local id = socket.listen("0.0.0.0",6005)
		   socket.start(id,function(id2,addr)
				   print(id,id2)
				   skynet.newservice(SERVICE_NAME,id2,addr)
		   end)
		   test_client()
   end)
end