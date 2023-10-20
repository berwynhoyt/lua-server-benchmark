local args = lws.parseargs(request.args)

response.body:write(
    "<html><body>",
    "<p>Hello     LWS-", _VERSION, "!</p>",
    "<p>PATH=" .. request.path .. "</p>")
if request.path=='/multiply' then
    response.body:write("<p>RESULT: ", args.a, "*", args.b, "=", math.floor(args.a*args.b), "</p>")
end
response.body:write("</body></html>\n")

response.headers['Content-Type'] = 'text/html'
