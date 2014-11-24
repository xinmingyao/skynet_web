local skynet = require "skynet"
local httpc = require "http.httpc"
local express = require "web.express"
skynet.start(function()
		print("http Server start")
		local web = express.app(8001,{
					     web_root="./skynet_web/test",
					     thread = 2
					     ,static_regular=".js|.html|.css|.pb"})
		--pattern handle
		web:use(".","/test/auth/tocken")
		web:listen()
		local header = {}
		local status, body = httpc.get("127.0.0.1:8001", "/test/user/index?id=1", {})
		print("========",status,body)

		local status, body = httpc.get("127.0.0.1:8001", "/test/user/index?tocken=1", {})
		print("========",status,body)

		local status, body1 = httpc.get("127.0.0.1:8001", "/test.html", {})
		print("========",status,body1)
		local status, body1 = httpc.get("127.0.0.1:8001", "/test.html", {})
		skynet.sleep(5000)
		skynet.exit()
end)
