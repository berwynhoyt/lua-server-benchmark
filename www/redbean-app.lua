local uri = GetPath()
Write(
    "<html><body>" ..
    "<p>Hello Redbean-" .. _VERSION .. "!</p>" ..
    "<p>PATH=" .. uri .. "</p>")
if uri=='/multiply' then
    local a, b = GetParam('a'), GetParam('b')
    Write("<p>RESULT: ".. a .. "*" .. b .. "=" .. math.floor(a*b) .. "</p>")
end
Write("</body></html>\n")

SetHeader('Content-Type', 'text/html')
