#!/usr/bin/env lua

local fastcgi = require 'wsapi.fastcgi'
local app = require 'app'
fastcgi.run(app.run)
