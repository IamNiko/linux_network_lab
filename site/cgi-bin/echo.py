#!/usr/bin/env python3
import cgi, html, os

print("Content-Type: text/html; charset=utf-8")
print()

form = cgi.FieldStorage()
pairs = {k: form.getvalue(k, "") for k in form.keys()}

print("""<!doctype html>
<html><head><meta charset="utf-8"><title>Echo</title></head><body>""")
print("<h1>Echo</h1>")

if pairs:
    print("<ul>")
    for k, v in pairs.items():
        print(f"<li><b>{html.escape(k)}</b>: {html.escape(str(v))}</li>")
    print("</ul>")
else:
    print("<p>Sin parámetros</p>")

print(f"<p>Método: {html.escape(os.environ.get('REQUEST_METHOD',''))}</p>")
print(f"<p>IP cliente: {html.escape(os.environ.get('REMOTE_ADDR',''))}</p>")
print("</body></html>")
