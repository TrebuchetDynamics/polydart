#!/usr/bin/env python3
"""Build a read-only Polygolem-to-Polydart inventory scaffold."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


SAFETY_TERMS = (
    "auth",
    "wallet",
    "relayer",
    "clob",
    "order",
    "enabletrading",
    "approval",
    "fund",
    "bridge",
    "private_key",
    "signer",
    "signature",
    "hmac",
)


def git_commit(path: Path) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--short", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""
    return result.stdout.strip()


def safety_review(feature: str) -> str:
    lowered = feature.lower()
    return "required" if any(term in lowered for term in SAFETY_TERMS) else "not_required"


def existing_path(root: Path, candidates: list[str]) -> str:
    for candidate in candidates:
        if (root / candidate).exists():
            return candidate
    return ""


def add_row(rows: list[dict[str, str]], root: Path, feature: str, source_path: str) -> None:
    name = feature.split("/", 1)[-1]
    polydart_path = existing_path(
        root,
        [
            f"lib/src/{name}",
            f"lib/src/{name}.dart",
            f"docs/{name}.md",
        ],
    )
    tests = existing_path(
        root,
        [
            f"test/{name}",
            f"test/{name}_test.dart",
        ],
    )
    rows.append(
        {
            "feature": feature,
            "polygolem_path": source_path,
            "polydart_path": polydart_path,
            "status": "unknown",
            "tests": tests,
            "safety_review": safety_review(feature),
            "next_action": "classify",
        }
    )


def build_inventory(root: Path) -> dict[str, object]:
    root = root.resolve()
    polygolem = root / "polygolem"
    rows: list[dict[str, str]] = []

    for parent, prefix in [
        (polygolem / "pkg", "pkg"),
        (polygolem / "internal", "internal"),
    ]:
        if parent.exists():
            for child in sorted(path for path in parent.iterdir() if path.is_dir()):
                add_row(rows, root, f"{prefix}/{child.name}", str(child.relative_to(root)))

    cli_dir = polygolem / "internal" / "cli"
    if cli_dir.exists():
        for file_path in sorted(cli_dir.glob("cmd_*.go")):
            add_row(
                rows,
                root,
                f"cli/{file_path.stem}",
                str(file_path.relative_to(root)),
            )

    docs_dir = polygolem / "docs"
    if docs_dir.exists():
        for file_path in sorted(docs_dir.glob("*.md")):
            add_row(
                rows,
                root,
                f"docs/{file_path.name}",
                str(file_path.relative_to(root)),
            )

    polygolem_commit = git_commit(polygolem)
    warnings: list[str] = []

    return {
        "source": "polygolem",
        "polygolem_commit": polygolem_commit,
        "warnings": warnings,
        "rows": rows,
    }


def markdown_table(inventory: dict[str, object]) -> str:
    rows = inventory["rows"]
    lines = [
        "# Polydart-Polygolem Inventory Scaffold",
        "",
        f"- Polygolem commit: `{inventory['polygolem_commit'] or 'unknown'}`",
        "",
    ]
    warnings = inventory["warnings"]
    if warnings:
        lines.extend(["## Warnings", ""])
        lines.extend(f"- {warning}" for warning in warnings)
        lines.append("")
    lines.extend(
        [
            "| Feature | Polygolem Path | Polydart Path | Status | Tests | Safety Review | Next Action |",
            "|---|---|---|---|---|---|---|",
        ]
    )
    for row in rows:
        lines.append(
            "| {feature} | {polygolem_path} | {polydart_path} | {status} | {tests} | {safety_review} | {next_action} |".format(
                **row
            )
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Polydart repository root")
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format",
    )
    args = parser.parse_args()

    inventory = build_inventory(Path(args.root))
    if args.format == "json":
        print(json.dumps(inventory, indent=2, sort_keys=True))
    else:
        print(markdown_table(inventory), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
