"""Dependency-free static checks; these do not replace rendered browser QA."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re

ROOT = Path(__file__).resolve().parent / "dist"


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.source = source
        self.ids = set()
        self.links = []
        self.h1s = 0
        self.main = 0
        self.feed(source.read_text(encoding="utf-8"))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            assert attrs["id"] not in self.ids, f"Duplicate ID in {self.source.name}"
            self.ids.add(attrs["id"])
        self.h1s += tag == "h1"
        self.main += tag == "main"
        assert tag not in {"script", "iframe", "form"}, "Unreviewed active content"
        if tag == "img":
            assert all(key in attrs for key in ("alt", "width", "height")), "Image accessibility/layout metadata missing"
        for key in ("href", "src"):
            if key in attrs:
                self.links.append((tag, attrs[key]))


pages = {p.resolve(): Page(p) for p in ROOT.glob("*.html")}
for source, page in pages.items():
    assert page.h1s == page.main == 1, f"Heading/main structure: {source.name}"
    html = source.read_text(encoding="utf-8")
    assert '<html lang="en">' in html and 'name="viewport"' in html
    assert "Content-Security-Policy" in html and "#main" in html
    for tag, href in page.links:
        url = urlsplit(href)
        if url.scheme:
            assert url.scheme in {"https", "mailto"}, f"Unsafe URL: {href}"
            assert tag == "a", f"External resource: {href}"
            continue
        assert not href.startswith("/"), f"Project-path-unsafe URL: {href}"
        target = (source.parent / unquote(url.path)).resolve() if url.path else source
        if target.is_dir():
            target /= "index.html"
        assert target.is_relative_to(ROOT.resolve()) and target.is_file(), f"Broken local link: {href}"
        if url.fragment:
            assert target in pages and url.fragment in pages[target].ids, f"Broken anchor: {href}"
    assert "privacy.html" in html and "terms.html" in html

for path in ROOT.rglob("*"):
    if path.is_file():
        assert path.name == ".nojekyll" or path.suffix.lower() in {".html", ".css", ".svg", ".png", ".txt"}, f"Unexpected published file: {path.name}"
        assert not re.search(r"client_secret|credential|token|passphrase", path.name, re.I)

css = (ROOT / "assets/site.css").read_text(encoding="utf-8")
for rule in ("focus-visible", "prefers-reduced-motion", "prefers-color-scheme:light", "max-width:600px", "max-width:900px"):
    assert rule in css, f"Missing responsive/accessibility rule: {rule}"


def luminance(color):
    if len(color) == 4:
        color = '#' + ''.join(v * 2 for v in color[1:])
    rgb = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    return sum(v * weight for v, weight in zip(linear, (.2126, .7152, .0722)))


for theme in (css.split("*{", 1)[0], css.split("@media(prefers-color-scheme:light)", 1)[1].split("}\n", 1)[0]):
    colors = dict(re.findall(r"--([a-z-]+):(#[0-9a-fA-F]{3,6})\b", theme))
    for foreground, background in (("ink", "bg"), ("muted", "bg"), ("muted", "surface"), ("accent", "bg"), ("on-accent", "accent")):
        a, b = sorted((luminance(colors[foreground]), luminance(colors[background])))
        assert (b + .05) / (a + .05) >= 4.5, f"Text contrast: {foreground}/{background}"
print(f"PASS: {len(pages)} pages; local links/anchors, semantic structure, static-only content, theme contrast and responsive/accessibility CSS.")
print("UNVERIFIED: rendered browser appearance, physical responsive/zoom and screen-reader interaction.")
