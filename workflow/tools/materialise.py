"""Copy a workflow script into the run folder, filling in its @TOKEN@ placeholders from the configuration.

Usage: materialise.py <config.sh> <run_root_windows> <source_script> <destination_script>

The scripts under workflow/ contain no machine-specific paths or sample dates. They use placeholders:
  @RUN_ROOT@        the run folder (written with the path separator style that follows the token)
  @<SETTING>@       any setting from the configuration file, e.g. @SAMPLE_END_YEAR@, @PAPER_CHECKS@
The run copy is written to <destination_script>. The script stops if a placeholder has no value.
"""
import re
import sys
from pathlib import Path


def read_config(path):
    """Read KEY="value" lines of a shell configuration file (no shell expansion except $RUN_ROOT)."""
    values = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        m = re.match(r'^\s*([A-Z][A-Z0-9_]*)=(["\']?)(.*?)\2\s*(#.*)?$', line)
        if m:
            values[m.group(1)] = m.group(3)
    return values


def fill(text, values, run_root):
    run_root = run_root.rstrip("\\/")

    def root(m):
        sep = m.group(1)
        if sep == "\\\\":  # inside a non-raw string literal with escaped backslashes
            return run_root.replace("\\", "\\\\") + sep
        if sep == "/":
            return run_root.replace("\\", "/") + sep
        return run_root + sep

    text = re.sub(r"@RUN_ROOT@(\\\\|\\|/)", root, text)
    # Elsewhere (e.g. Path('@RUN_ROOT@')) use forward slashes, which are safe in any string literal.
    text = text.replace("@RUN_ROOT@", run_root.replace("\\", "/"))

    def setting(m):
        key = m.group(1)
        if key not in values:
            raise SystemExit(f"No value for placeholder @{key}@ (add it to the configuration)")
        return values[key]

    return re.sub(r"@([A-Z][A-Z0-9_]*)@", setting, text)


if __name__ == "__main__":
    config, run_root, src, dest = sys.argv[1:5]
    # surrogateescape keeps any non-UTF-8 bytes (some SAS sources are Windows-1252) unchanged.
    text = Path(src).read_text(encoding="utf-8-sig", errors="surrogateescape")
    out = fill(text, read_config(config), run_root)
    Path(dest).parent.mkdir(parents=True, exist_ok=True)
    Path(dest).write_text(out, encoding="utf-8", errors="surrogateescape")
