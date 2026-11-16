#!/usr/bin/env python3
"""Build and verify a WoW-installable BagCleaner ZIP using Python stdlib only."""
from __future__ import annotations
import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "BagCleaner"


def toc_manifest() -> tuple[str, list[Path]]:
    toc = ADDON / "BagCleaner.toc"
    if not toc.is_file():
        raise ValueError("BagCleaner/BagCleaner.toc is missing")
    lines = toc.read_text(encoding="utf-8-sig").splitlines()
    version = None
    refs = []
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if line.startswith("##"):
            m = re.match(r"##\s*Version\s*:\s*(\S+)\s*$", line, flags=re.I)
            if m:
                version = m.group(1)
            continue
        if line.startswith("#"):
            continue
        # Prevent accidental packaging outside BagCleaner via crafted TOC paths.
        relative = PurePosixPath(line.replace("\\", "/"))
        if relative.is_absolute() or ".." in relative.parts or ":" in line:
            raise ValueError(f"Unsafe file name in toc: {line}")
        path = ADDON.joinpath(*relative.parts)
        if not path.is_file():
            raise ValueError(f"Referenced add-on file missing: {relative}")
        refs.append(path)
    if not version or not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.]+)?", version):
        raise ValueError("BagCleaner.toc has no valid '## Version: x.y.z'")
    if not refs:
        raise ValueError("BagCleaner.toc references no Lua/XML files")
    return version, [toc, *refs]


def build(tag: str | None, output_dir: Path) -> Path:
    version, files = toc_manifest()
    expected = f"v{version}"
    if tag and tag != expected:
        raise ValueError(f"GitHub tag '{tag}' must match BagCleaner.toc Version '{version}' ({expected})")
    for doc in ("README.md", "CHANGELOG.md"):
        if (ADDON / doc).is_file():
            files.append(ADDON / doc)
    files = sorted(set(files), key=lambda p: p.relative_to(ADDON).as_posix())
    output_dir.mkdir(parents=True, exist_ok=True)
    filename = f"BagCleaner_{expected}_Forever.zip"
    target = output_dir / filename
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for file in files:
            relative = PurePosixPath("BagCleaner") / file.relative_to(ADDON).as_posix()
            # Reproducible timestamps and permission bits; no project-root nesting.
            info = zipfile.ZipInfo(str(relative), date_time=(2020, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (0o100644 << 16)
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, file.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(target) as archive:
        entries = archive.namelist()
        expected_entries = {str(PurePosixPath("BagCleaner") / p.relative_to(ADDON).as_posix()) for p in files}
        if set(entries) != expected_entries or archive.testzip() is not None:
            raise ValueError("Release ZIP failed integrity/contents check")
        if "BagCleaner/BagCleaner.toc" not in entries:
            raise ValueError("WoW addon TOC is missing from ZIP")
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    (output_dir / f"{filename}.sha256").write_text(f"{digest}  {filename}\n", encoding="utf-8")
    print(f"Created {target.relative_to(ROOT) if target.is_relative_to(ROOT) else target}")
    print(f"SHA256 {digest}")
    print(f"Contents: {', '.join(p.name for p in files)}")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description="Make a reproducible BagCleaner GitHub Release asset")
    parser.add_argument("--tag", default=None, help="Expected GitHub tag, e.g. v1.4.1; must match .toc")
    parser.add_argument("--out", default="dist", help="Output folder, relative to repository root")
    args = parser.parse_args()
    try:
        out = Path(args.out)
        if not out.is_absolute():
            out = ROOT / out
        build(args.tag, out)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"Build failed: {exc}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
