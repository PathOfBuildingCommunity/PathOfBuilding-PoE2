-- Start a server
local socket = require("socket")
local server = assert(socket.bind("*", 49082) or socket.bind("*", 49083) or socket.bind("*", 49084))
server:settimeout(30)
local host, port = server:getsockname()
ConPrintf("Server started on %s:%s", host, port)

local code, state
local client = server:accept()
if client then
	client:settimeout(10)
	local request, err = client:receive("*l")
	
	if not err and request then
		local _, _, method, path, version = request:find("^(%S+)%s(%S+)%s(%S+)")
		if method ~= "GET" then
			return
		end
		local queryParams = {}
		for k, v in path:gmatch("(%w+)=(%w+)") do
			queryParams[k] = v
		end

		-- TODO: Handle errors (they come back as 'error' and 'error_description' query parameters)
		-- TODO: Create a proper page the user sees, and close tab with Javascript
		-- Send HTTP Response
		local responseOk = [[
HTTP/1.1 200 OK
Content-Type: text/html

<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>PoB 2 - Authentication Complete</title>
	<style>
		body {
			font-family: Arial, sans-serif;
			background: #121212;
			color: #fff;
			display: flex;
			justify-content: center;
			align-items: center;
			height: 100vh;
			margin: 0;
		}
		.container {
			display: flex;
			flex-direction: column;
			align-items: center;
		}
		.card {
			background: #1E1E1E;
			padding: 20px;
			border-radius: 10px;
			box-shadow: 0px 4px 10px rgba(255, 255, 255, 0.1);
			width: 90%;
			max-width: 400px;
			text-align: center;
		}
		.card h1 {
			font-size: 24px;
			color: #4CAF50;
			margin-bottom: 10px;
		}
		.card p {
			font-size: 18px;
			margin-bottom: 15px;
		}
		.close-button {
			padding: 10px 20px;
			background: #4CAF50;
			color: white;
			border: none;
			border-radius: 5px;
			cursor: pointer;
			font-size: 16px;
			transition: background 0.3s;
		}
		.close-button:hover {
			background: #45a049;
		}
	</style>
</head>
<body>
	<div class="container">
		<div class="card">
			<h1>PoB 2 - Authentication Successful</h1>
			<p>✅ Your authentication is complete! You can now return to the app.</p>
			<button class="close-button" onclick="window.close()">Close</button>
		</div>
	</div>
</body>
</html>
]]
		client:send(responseOk)
		code = queryParams["code"]
		state = queryParams["state"]
	end
	client:close()
end
return code, state, port
