"""Fail closed when restricted data or credential files are tracked by Git."""

from pathlib import Path
import subprocess


FORBIDDEN_SUFFIXES = {
    ".csv",
    ".dta",
    ".parquet",
    ".sas7bdat",
    ".xls",
    ".xlsx",
}
FORBIDDEN_NAMES = {".env", "credentials.json", "secrets.json"}


def find_violations(paths: list[str]) -> list[str]:
    """Return tracked paths that could contain licensed data or credentials."""
    violations = []
    for raw_path in paths:
        path = Path(raw_path)
        if path.name.lower() in FORBIDDEN_NAMES or path.suffix.lower() in FORBIDDEN_SUFFIXES:
            violations.append(path.as_posix())
    return sorted(violations)


def tracked_files() -> list[str]:
    """Read the repository's tracked-file list without examining ignored data."""
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [path for path in result.stdout.split("\0") if path]


def main() -> None:
    violations = find_violations(tracked_files())
    if violations:
        joined = "\n  - ".join(violations)
        raise SystemExit(f"Restricted file types are tracked:\n  - {joined}")
    print("repository safety audit passed")


if __name__ == "__main__":
    main()
