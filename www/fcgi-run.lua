#!/usr/bin/env lua

local fastcgi = require 'wsapi.fastcgi'
local app = require 'fcgi-app'
fastcgi.run(app.run)
