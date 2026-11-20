"""Anonymous public deployment checks. Does not change hosting or Google state."""
from argparse import ArgumentParser
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent / "dist"
BASE = "https://2hik4.github.io/Todorbit/"
RELEASE_BASE = "https://github.com/2HIK4/Todorbit/releases"
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
    expected = path.read_bytes()
    # Git normalizes text line endings on the Linux Actions checkout.
    if path.suffix != ".png":
        expected = expected.replace(b"\r\n", b"\n")
    assert public == expected, f"Published bytes differ: {relative}"
    return {"file": relative, "sha256": sha256(public).hexdigest()}


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.external = set()

    def handle_starttag(self, tag, attrs):
        href = dict(attrs).get("href", "")
        if tag == "a" and href.startswith("https://"):
            self.external.add(href)


def latest_coordinated_release(releases):
    published_betas = (r for r in releases if r["prerelease"] and not r["draft"])
    for release in sorted(published_betas, key=lambda r: r["published_at"], reverse=True):
        tag = release["tag_name"]
        version = tag.removeprefix("v")
        checksums = {
            f"Todorbit-{version}-SHA256SUMS.txt": [
                f"Todorbit-{version}-win-x64-setup.exe",
                f"Todorbit-{version}-win-x64-portable.zip",
            ],
            "ANDROID-SHA256SUMS.txt": [f"Todorbit-{version}-android-universal.apk"],
        }
        assets = {asset["name"]: asset for asset in release["assets"]}
        required = set(checksums).union(*checksums.values())
        if required <= assets.keys():
            return tag, checksums, assets
    raise AssertionError("No published pre-release with both Windows and Android packages and checksums")


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--preview", action="store_true", help="Check preview links without comparing deployed bytes.")
    args = parser.parse_args()

    links = Links()
    for page in ROOT.glob("*.html"):
        links.feed(page.read_text(encoding="utf-8"))
    releases = json.loads(request(REPO + "/releases?per_page=100"))
    tag, checksums, assets = latest_coordinated_release(releases)
    packages = [name for names in checksums.values() for name in names]
    required_names = [*packages, *checksums]
    expected_links = {assets[name]["browser_download_url"] for name in required_names}
    download_links = {link for link in links.external if link.startswith(RELEASE_BASE + "/download/")}
    assert download_links == expected_links, f"Update the website's package and checksum links to {tag}"
    assert RELEASE_BASE + "/tag/" + tag in links.external, f"Link to the release notes for {tag}"
    for filename, platform_packages in checksums.items():
        body = request(assets[filename]["browser_download_url"]).decode("utf-8")
        entries = (line.split(maxsplit=1) for line in body.splitlines() if line.strip())
        hashes = {name: digest for digest, name in entries}
        for name in platform_packages:
            assert "sha256:" + hashes[name] == assets[name]["digest"], f"Checksum metadata differs for {name}"

    file_hashes = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        if not args.preview:
            assert request(BASE) == (ROOT / "index.html").read_bytes().replace(b"\r\n", b"\n"), (
                "The live homepage differs from this checkout. Use --preview before approved deployment."
            )
            files = sorted(p for p in ROOT.rglob("*") if p.is_file())
            file_hashes = list(pool.map(check_file, files))
        list(pool.map(lambda url: request(url, "HEAD"), sorted(links.external)))
    print(json.dumps({
        "mode": "preview" if args.preview else "published",
        "base": BASE,
        "public_prerelease": tag,
        "files": file_hashes,
        "external_links": len(links.external),
        "packages_with_matching_sha256_metadata": packages,
        "result": "PASS",
    }, indent=2))


if __name__ == "__main__":
    main()
