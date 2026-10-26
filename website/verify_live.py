"""Anonymous public deployment checks. Does not change hosting or Google state."""
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent / "dist"
BASE = "https://2hik4.github.io/Todorbit/"
REPO = "https://api.github.com/repos/2HIK4/Todorbit"
HEADERS = {"User-Agent": "Todorbit-website-deployment-check", "Accept": "*/*"}


def request(url, method="GET"):
    with urlopen(Request(url, headers=HEADERS, method=method), timeout=30) as response:
        assert response.status == 200, f"HTTP {response.status}: {url}"
        assert response.url.startswith("https://"), f"Non-HTTPS final URL: {url}"
        return response.read() if method == "GET" else b""


def check_file(path):
    relative = path.relative_to(ROOT).as_posix()
    public = request(urljoin(BASE, relative))
    assert public == path.read_bytes(), f"Published bytes differ: {relative}"
    return {"file": relative, "sha256": sha256(public).hexdigest()}


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.external = set()

    def handle_starttag(self, tag, attrs):
        href = dict(attrs).get("href", "")
        if tag == "a" and href.startswith("https://"):
            self.external.add(href)


def main():
    assert request(BASE) == (ROOT / "index.html").read_bytes()
    files = sorted(p for p in ROOT.rglob("*") if p.is_file())
    links = Links()
    for page in ROOT.glob("*.html"):
        links.feed(page.read_text(encoding="utf-8"))
    releases = json.loads(request(REPO + "/releases?per_page=100"))
    latest = max((r for r in releases if not r["draft"]), key=lambda r: r["published_at"])
    download_links = {link for link in links.external if "/releases/download/" in link}
    assert len(download_links) == 2, "Expected installer and portable downloads"
    assets = {asset["browser_download_url"] for asset in latest["assets"]}
    assert download_links <= assets, "Downloads do not belong to latest public release"
    with ThreadPoolExecutor(max_workers=6) as pool:
        hashes = list(pool.map(check_file, files))
        list(pool.map(lambda url: request(url, "HEAD"), sorted(links.external)))
    print(json.dumps({"base": BASE, "public_release": latest["tag_name"],
                      "files": hashes, "external_links": len(links.external),
                      "result": "PASS", "rendered_browser_qa": "UNVERIFIED"}, indent=2))


if __name__ == "__main__":
    main()
