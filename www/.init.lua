-- Lua init script for redbean
-- This functionality could be implemented in index.lua or even multiply.lua but this is faster (per redbean docs)

OnHttpRequest = loadfile('www/redbean-app.lua')
