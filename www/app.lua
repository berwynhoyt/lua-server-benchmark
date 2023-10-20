#!/usr/bin/env wsapi.cgi

local coroutine = require 'coroutine'
local math = require 'math'

local M = {}
_ENV = M
_VERSION = _VERSION or 'Lua ?.?'

function run(wsapi_env)
  local headers = { ["Content-type"] = "text/html" }

  local function hello_text()
    coroutine.yield("<html><body>" ..
      "<p>Hello   WSAPI-" .. _VERSION .. "!</p>" ..
      "<p>PATH=" .. wsapi_env.DOCUMENT_URI .. "</p>")
    if wsapi_env.DOCUMENT_URI=='/multiply' then
        coroutine.yield("<p>RESULT: " .. wsapi_env.ARG_A .. "*" .. wsapi_env.ARG_B .. "=" .. math.floor(wsapi_env.ARG_A*wsapi_env.ARG_B) .. "</p>")
    end
    coroutine.yield("</body></html>\n")
  end

  return 200, headers, coroutine.wrap(hello_text)
end

M.run = run

return M
