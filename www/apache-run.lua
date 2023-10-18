M = {}

function handle(r)
    r.content_type = "text/plain"
    r:puts("<html><body>" ..
        "<p>Hello Apache-" .. _VERSION .. "!</p>" ..
        "<p>PATH=" .. r.uri .. "</p>")
    if r.uri=='/multiply' then
        local args = r:parseargs()
        r:puts("<p>RESULT: " .. args.a .."*" .. args.b .. "=" .. args.a*args.b .. "</p>")
    end
    r:puts("</body></html>\n")
    return 0
end

M.handle = handle

return M
