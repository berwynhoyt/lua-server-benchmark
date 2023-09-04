local coroutine = require "coroutine"

function run(wsapi_env)
  local headers = { ["Content-type"] = "text/html" }

  local function hello_text()
    coroutine.yield("<html><body>" ..
      "<p>Hello uWSGI!</p>" ..
--~       "<p>PATH=" .. wsapi_env.DOCUMENT_URI .. "</p>" ..
      "")
--~     if wsapi_env.DOCUMENT_URI=='/multiply' then
--~         coroutine.yield("<p>RESULT: " .. wsapi_env.ARG_A .. "*" .. wsapi_env.ARG_B .. "=" .. wsapi_env.ARG_A*wsapi_env.ARG_B .. "</p>")
--~     end
    coroutine.yield("</body></html>\n")
  end

  return 200, headers, coroutine.wrap(hello_text)
end

return run
