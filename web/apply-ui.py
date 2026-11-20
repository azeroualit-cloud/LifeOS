"""Inserisce web/ui.css in web/app.html (un solo <style id="lifeos-ui">). Idempotente."""
import re
from pathlib import Path
base = Path(__file__).parent
html = (base / "app.html").read_text(encoding="utf-8")
css = (base / "ui.css").read_text(encoding="utf-8")
block = '<style id="lifeos-ui">\n' + css + "</style>\n"
html = re.sub(r"<style[^>]*>.*?</style>\n?", "", html, flags=re.S)
assert "</head>" in html
html = html.replace("</head>", block + "</head>", 1)
(base / "app.html").write_text(html, encoding="utf-8")
print("ui.css applicato:", len(css), "byte")
