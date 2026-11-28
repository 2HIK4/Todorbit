"""Check maintained public Markdown paths, images, and heading links offline."""
from argparse import ArgumentParser
from collections import Counter
from html import unescape
import json
import os
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
PUBLIC_DOCS = (
    "AGENTS.md", "README.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md",
    "SECURITY.md", "THIRD_PARTY_NOTICES.md", "docs/README.md",
    "docs/SCREENSHOTS.md", "docs/FEATURES.md", "docs/PLATFORM_SUPPORT.md",
    "docs/INSTALLATION.md", "docs/PRIVACY.md", "docs/OPEN_SOURCE_EVIDENCE.md",
    "docs/OPEN_SOURCE_READINESS.md", "docs/CONTRIBUTOR_TASKS.md",
    "docs/ROADMAP.md", "website/README.md",
)
INLINE_LINK = re.compile(
    r"\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+\"[^\"\n]*\")?\s*\)"
)
HTML_TARGET = re.compile(r"""<(?:img|a)\b[^>]*?\b(?:src|href)=["']([^"']+)""", re.I)
HEADING = re.compile(r"^ {0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$")
EXPLICIT_ANCHOR = re.compile(r"""<(?:a|h[1-6])\b[^>]*?\b(?:id|name)=["']([^"']+)""", re.I)


def markdown_lines(text):
    """Remove fenced examples before scanning link destinations and headings."""
    opening = None
    for line in text.splitlines():
        fence = re.match(r"^ {0,3}([~]{3,}|[\x60]{3,})(.*)$", line)
        if fence:
            marker = fence[1]
            if opening is None:
                opening = marker
            elif marker[0] == opening[0] and len(marker) >= len(opening) and not fence[2].strip():
                opening = None
            continue
        if opening is None:
            yield line


def anchors(path):
    used = set()
    counts = Counter()
    lines = list(markdown_lines(path.read_text(encoding="utf-8-sig")))
    for index, line in enumerate(lines):
        used.update(EXPLICIT_ANCHOR.findall(line))
        heading = HEADING.match(line)
        if heading:
            label = heading[1]
        elif line.strip() and index + 1 < len(lines) and re.fullmatch(r" {0,3}(=+|-+)\s*", lines[index + 1]):
            label = line.strip()
        else:
            continue
        label = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", label)
        label = re.sub(r"<[^>]+>", "", label)
        slug = re.sub(r"[^\w -]", "", unescape(label).lower()).replace(" ", "-")
        candidate = slug
        while candidate in used:
            counts[slug] += 1
            candidate = f"{slug}-{counts[slug]}"
        used.add(candidate)
    return used


def exact_path(path, root):
    """Check spelling even on filesystems with case-insensitive lookup."""
    if not path.is_relative_to(root) or not path.resolve().is_relative_to(root):
        return False
    parent = root
    for part in path.relative_to(root).parts:
        if not parent.is_dir() or all(child.name != part for child in parent.iterdir()):
            return False
        parent /= part
    return parent.exists()


def validate(root, filenames):
    results = []
    known_anchors = {}
    checked = 0
    for filename in filenames:
        source = Path(os.path.abspath(root / filename))
        if not exact_path(source, root) or not source.is_file():
            results.append(f"{filename}: missing Markdown source")
            continue
        for line in markdown_lines(source.read_text(encoding="utf-8-sig")):
            destinations = [match[1] or match[2] for match in INLINE_LINK.finditer(line)]
            destinations.extend(HTML_TARGET.findall(line))
            for destination in destinations:
                url = urlsplit(unescape(destination))
                if url.scheme or url.netloc:
                    continue
                checked += 1
                target = Path(os.path.abspath(source.parent / unquote(url.path))) if url.path else source
                if not exact_path(target, root):
                    results.append(f"{filename}: broken path or case mismatch: {destination}")
                    continue
                if target.is_dir() and (target / "README.md").is_file():
                    target /= "README.md"
                if url.fragment and target.suffix.lower() == ".md":
                    if target not in known_anchors:
                        known_anchors[target] = anchors(target)
                    if unquote(url.fragment) not in known_anchors[target]:
                        results.append(f"{filename}: missing heading: {destination}")
    return {"files": len(filenames), "local_destinations": checked, "errors": results}


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", help="Markdown paths relative to the repository root")
    parser.add_argument("--all", action="store_true", help="Also scan historical docs and manuals")
    parser.add_argument("--json", action="store_true", help="Emit a machine-readable result")
    args = parser.parse_args()
    if args.all and args.files:
        parser.error("use --all or explicit files")
    filenames = tuple(args.files) or PUBLIC_DOCS
    if args.all:
        filenames = sorted(set(PUBLIC_DOCS).union(path.relative_to(ROOT).as_posix() for path in (ROOT / "docs").rglob("*.md")))
    result = validate(ROOT, filenames)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for issue in result["errors"]:
            print(issue)
        print(f'{result["files"]} Markdown files, {result["local_destinations"]} local destinations, {len(result["errors"])} errors')
    return bool(result["errors"])


if __name__ == "__main__":
    raise SystemExit(main())
