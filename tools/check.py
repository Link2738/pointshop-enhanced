#!/usr/bin/env python3
"""
Static checks for this addon's Lua.

Every check here exists because something specific went wrong and was not caught by reading
the code. They are cheap, they need no interpreter for the Lua itself, and they are meant to
be run before a change is called finished.

    python3 tools/check.py              # everything, over lua/
    python3 tools/check.py structure    # one check
    python3 tools/check.py --files a.lua b.lua

Exit code is 1 if anything failed, so it can gate a commit.

THIS SCRIPT MUST STAY READ-ONLY.

It is on the permission allowlist by path, which is safe only because of what it does: it
reads files, matches patterns, and prints. That makes allowing it a grant to run *this
program*, not a grant to run code -- the distinction that keeps `python3 -c` and `python3 -`
off the list.

Adding anything that writes, deletes, moves or executes -- a --fix flag being the obvious
temptation -- silently converts an allowlisted read into an allowlisted write, and nobody
would see it happen because the permission entry does not change. If this ever needs to
modify files, that belongs in a separate script that is not allowlisted.
"""

import os
import re
import sys
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------------------
# LEXER
#
# Regex over raw Lua is wrong and quietly so: an apostrophe in a comment opens a string
# literal that swallows real code until the next one, and a corrupted rename came out of
# exactly that. Everything below works on source with comments and strings blanked out.
# ---------------------------------------------------------------------------

def scan(src):
    """Yield (start, end, kind) runs where kind is code / comment / string."""
    runs, i, n, start, kind, quote = [], 0, len(src), 0, "code", None

    def push(end, k):
        if end > start:
            runs.append((start, end, k))

    while i < n:
        c = src[i]
        if kind == "code":
            if src.startswith("--[[", i):
                push(i, "code"); start = i; kind = "blockcomment"; i += 4; continue
            if src.startswith("--", i):
                push(i, "code"); start = i; kind = "linecomment"; i += 2; continue
            if c in "\"'":
                push(i, "code"); start = i; kind = "string"; quote = c; i += 1; continue
            if src.startswith("[[", i):
                push(i, "code"); start = i; kind = "longstring"; i += 2; continue
            i += 1
        elif kind == "blockcomment":
            if src.startswith("]]", i):
                i += 2; push(i, "comment"); start = i; kind = "code"; continue
            i += 1
        elif kind == "linecomment":
            if c == "\n":
                push(i, "comment"); start = i; kind = "code"; continue
            i += 1
        elif kind == "string":
            if c == "\\":
                i += 2; continue
            if c == quote:
                i += 1; push(i, "string"); start = i; kind = "code"; continue
            i += 1
        elif kind == "longstring":
            if src.startswith("]]", i):
                i += 2; push(i, "string"); start = i; kind = "code"; continue
            i += 1

    push(n, kind if kind != "code" else "code")
    return runs


def code_only(src):
    """Source with comments and strings replaced by spaces, so offsets still line up."""
    return "".join(
        src[a:b] if k == "code" else re.sub(r"\S", " ", src[a:b])
        for a, b, k in scan(src)
    )


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def line_of(text, offset):
    return text[:offset].count("\n") + 1


# ---------------------------------------------------------------------------
# CHECKS
# ---------------------------------------------------------------------------

TOKENS = re.compile(r"(?<![\w.])(function|then|do|end|elseif|repeat|until)(?![\w])")


def check_structure(files):
    """
    Every top-level function closes before the next one opens.

    Counting `function`/`end` and comparing totals is not enough: a block move once left one
    function unclosed and dropped its `end` after the NEXT function, so the totals balanced
    perfectly on a file that would not load. Depth tracking catches the migration.
    """
    problems = []
    for path in files:
        code = code_only(read(path))
        depth, open_fn = 0, None

        for m in TOKENS.finditer(code):
            tok = m.group(1)
            line = code[:m.start()].count("\n") + 1
            src_line = code.split("\n")[line - 1]

            if tok == "elseif":
                # `elseif cond then` supplies a `then` that opens nothing - the enclosing
                # `if` already did, and one `end` closes the whole chain.
                depth -= 1
            elif tok in ("function", "then", "do", "repeat"):
                if tok == "function" and re.match(r"^(local\s+)?function", src_line):
                    if depth != 0 and open_fn is not None:
                        problems.append(
                            f"{path}:{line}: top-level function starts at depth {depth} "
                            f"(the one from line {open_fn} never closed)")
                    if depth == 0:
                        open_fn = line
                depth += 1
            else:  # end / until
                depth -= 1
                if depth == 0:
                    open_fn = None
                if depth < 0:
                    problems.append(f"{path}:{line}: unmatched 'end'")
                    depth = 0

        if depth != 0:
            problems.append(f"{path}: ends at depth {depth} (missing {depth} 'end')")

    return problems


def check_declarations(files):
    """
    No file-scope local is called above its own declaration.

    A local is nil until its declaration runs, and calling one early is not an error at load
    time - the file simply dies at that line, taking every function below it with it. That
    cost six debugging passes once: `local PLAYER = FindMetaTable("Player")` sat 68 lines
    below its first use, so half a file silently never loaded.
    """
    problems = []
    for path in files:
        code = code_only(read(path))
        declared = {}
        for m in re.finditer(r"^local(?:\s+function)?\s+([A-Za-z_]\w*)", code, re.M):
            declared.setdefault(m.group(1), m.start())

        for name, pos in declared.items():
            for use in re.finditer(r"(?<![\w.:])" + re.escape(name) + r"\s*\(", code):
                if use.start() < pos:
                    problems.append(
                        f"{path}:{line_of(code, use.start())}: '{name}' called before its "
                        f"declaration on line {line_of(code, pos)}")
                    break
    return problems


def check_paint_allocation(files):
    """
    No Color() built inside a paint function.

    Paint runs every frame for every visible panel, so a Color() in one is garbage every
    frame. cl_theme.lua's own header documents this; the check is here because documenting it
    did not stop it happening.
    """
    problems = []
    for path in files:
        lines = read(path).split("\n")
        in_paint, depth, started = False, 0, 0

        for i, raw in enumerate(lines, 1):
            line = raw.strip()
            if line.startswith("--"):
                continue

            if re.search(r"\.(Paint|PaintOver)\s*=\s*function|function\s+\w+[:.]Paint", line):
                in_paint, depth, started = True, 0, i

            if in_paint:
                depth += line.count("function") - len(re.findall(r"(?<![\w.])end(?![\w])", line))
                if re.search(r"(?<![\w.])Color\s*\(", line):
                    problems.append(f"{path}:{i}: Color() allocated inside a paint function")
                if depth <= 0 and i > started:
                    in_paint = False
    return problems


def check_seeding(files):
    """
    Every seeded control guards its change callback.

    DNumSlider and DComboBox do not fire their callbacks from SetValue/AddChoice directly -
    they fire a frame later, once the internal control settles, which is AFTER the callback
    has been wired up. So filling a panel in with its current values arrives at the caller as
    the user having changed every one of them. That is what made opening the layout panel
    count as editing the theme.
    """
    problems = []
    for path in files:
        lines = read(path).split("\n")
        for i, raw in enumerate(lines):
            if raw.strip().startswith("--"):
                continue
            if not re.search(r":SetValue\(|:AddChoice\(", raw):
                continue

            window = "\n".join(lines[i:i + 14])
            if not re.search(r"OnValueChanged|OnSelect|OnChange", window):
                continue

            around = "\n".join(lines[max(0, i - 4):i + 16])
            if "_seeding" not in around:
                problems.append(
                    f"{path}:{i + 1}: control seeded next to a change callback with no "
                    f"_seeding guard")
    return problems


def check_members(files):
    """
    Every PS.Theme.* and PS.UI.* reference resolves to a definition.

    Catches a member renamed in one place and not another, which reads as nil at runtime and
    usually shows up as something silently not drawing.
    """
    theme = read(os.path.join(ROOT, "lua/pointshop/cl_theme.lua"))
    ui = read(os.path.join(ROOT, "lua/pointshop/cl_ui.lua"))

    defined_t = (set(re.findall(r"^function T\.([A-Za-z0-9_]+)", theme, re.M))
                 | set(re.findall(r"^T\.([A-Za-z0-9_]+)\s*=", theme, re.M)))
    defined_u = (set(re.findall(r"^function UI\.([A-Za-z0-9_]+)", ui, re.M))
                 | set(re.findall(r"^UI\.([A-Za-z0-9_]+)\s*=", ui, re.M)))

    # Assigned from outside the theme file counts as defined - undeclared, but real.
    for path in files:
        code = code_only(read(path))
        defined_t |= set(re.findall(r"PS\.Theme\.([A-Za-z0-9_]+)\s*=", code))
        defined_u |= set(re.findall(r"PS\.UI\.([A-Za-z0-9_]+)\s*=", code))

    problems, seen = [], set()
    for path in files:
        code = code_only(read(path))
        for name in re.findall(r"PS\.Theme\.([A-Za-z0-9_]+)", code):
            if name not in defined_t and (path, name) not in seen:
                seen.add((path, name))
                problems.append(f"{path}: PS.Theme.{name} is never defined")
        for name in re.findall(r"PS\.UI\.([A-Za-z0-9_]+)", code):
            if name not in defined_u and (path, name) not in seen:
                seen.add((path, name))
                problems.append(f"{path}: PS.UI.{name} is never defined")
    return problems


def check_palette(files):
    """
    Every colour token and metric is read by something, and every one a look sets exists.

    A preset naming a token that does not exist fails silently - T.Apply skips unknown keys -
    so a mistyped entry in a look file is invisible until someone notices a colour that will
    not change.
    """
    theme = read(os.path.join(ROOT, "lua/pointshop/cl_theme.lua"))
    colours = set(re.findall(r"^T\.([A-Za-z0-9_]+)\s*=\s*Color", theme, re.M))

    start = theme.index("T.Metrics = {")
    metrics = set(re.findall(r"^\t([A-Za-z0-9_]+)\s*=", theme[start:theme.index("\n}", start)], re.M))

    # A look's `styles` block is keyed by widget style name, not by token, so those keys sit
    # at the same indent as its colours and metrics without being either.
    sel = theme.index("T.Selectable = {")
    styles = set(re.findall(r"^\t([A-Za-z0-9_]+)\s*=\s*\{", theme[sel:theme.index("\n}", sel)], re.M))

    problems = []
    for path in glob.glob(os.path.join(ROOT, "lua/pointshop/cl_theme_*.lua")):
        src = read(path)
        for name in set(re.findall(r"^\t\t([A-Za-z0-9_]+)\s*=", src, re.M)):
            if name not in colours and name not in metrics and name not in styles:
                problems.append(f"{path}: '{name}' is neither a colour token, a metric, "
                                f"nor a widget style")

    used = set()
    for path in files:
        code = code_only(read(path))
        used |= set(re.findall(r"(?:PS\.Theme|T)\.([A-Za-z0-9_]+)", code))
        used |= set(re.findall(r"METRIC_(?:BASE|DEFAULTS)\.([A-Za-z0-9_]+)", code))
    for path in glob.glob(os.path.join(ROOT, "lua/pointshop/cl_theme_*.lua")):
        used |= set(re.findall(r"^\t\t([A-Za-z0-9_]+)\s*=", read(path), re.M))

    for name in sorted(colours - used):
        problems.append(f"colour token T.{name} is never read")
    return problems


def check_netstrings(files):
    """
    Every net message name is registered server-side.

    util.AddNetworkString has to run on the server for a name to exist on the wire. Miss one
    and net.Start errors at the moment someone uses the feature - which is usually not the
    moment anybody is testing it.
    """
    registered, used = set(), {}
    for path in files:
        code = code_only(read(path))
        # Both quote styles. Matching only double quotes reported all 26 of this addon's
        # working messages as unregistered, because sv_init.lua registers them with single
        # quotes - a checker that cries wolf is worse than no checker.
        registered |= set(re.findall(r'util\.AddNetworkString\(\s*[\'"]([^\'"]+)[\'"]',
                                     read(path)))
        for m in re.finditer(r'net\.(?:Start|Receive)\(\s*[\'"]([^\'"]+)[\'"]', read(path)):
            used.setdefault(m.group(1), path)

    return [f"{path}: net message '{name}' is never registered with util.AddNetworkString"
            for name, path in sorted(used.items()) if name not in registered]


def check_globals(files):
    """
    No accidental globals at file scope.

    A missing `local` in Lua silently creates a global, which then collides with every other
    addon on the server. Assignments to a known table (PS.x, T.x) are fine; a bare NAME = is
    not.
    """
    # PS_-prefixed globals are this addon's deliberate cross-file interface (PS_RemovalQueue,
    # PS_DELTA_ADD, and so on), so they are not accidents.
    known = re.compile(r"^(PS|PS_\w+|T|UI|CATEGORY|ITEM|SWEP|GM|PANEL|_G)$")

    problems = []
    for path in files:
        code = code_only(read(path))
        for m in re.finditer(r"^([A-Za-z_]\w*)\s*=[^=]", code, re.M):
            name = m.group(1)
            if known.match(name) or name in ("hook", "net", "concommand"):
                continue

            # A field inside a table constructor sits at brace depth > 0 and is not an
            # assignment at all. Mis-indenting one to column 0 made CardMenuBG in the theme
            # panel's LABELS table look like a global.
            if code.count("{", 0, m.start()) > code.count("}", 0, m.start()):
                continue

            problems.append(f"{path}:{line_of(code, m.start())}: '{name}' assigned without "
                            f"'local' - this creates a global")
    return problems


def check_metrics_defined(files):
    """
    Every metric read is one that exists.

    A metric that does not exist reads as nil, and the first thing done with it is almost
    always arithmetic - so a typo is a crash in a paint or layout function rather than a
    quiet wrong value.
    """
    theme = read(os.path.join(ROOT, "lua/pointshop/cl_theme.lua"))
    start = theme.index("T.Metrics = {")
    defined = set(re.findall(r"^\t([A-Za-z0-9_]+)\s*=",
                             theme[start:theme.index("\n}", start)], re.M))

    problems, seen = [], set()
    for path in files:
        code = code_only(read(path))
        for m in re.finditer(r"(?:M\(\)|\bM|PS\.Theme\.Metrics|T\.Metrics)\.([A-Za-z0-9_]+)", code):
            name = m.group(1)
            if name not in defined and (path, name) not in seen:
                seen.add((path, name))
                problems.append(f"{path}:{line_of(code, m.start())}: metric '{name}' is not "
                                f"defined in T.Metrics")
    return problems


def check_styles(files):
    """
    Every widget style points at a colour that exists.

    A style holds direct references to Color tables. One naming a token that is not there
    stores nil, and the painter hands nil to surface.SetDrawColor the first time that state
    is drawn.
    """
    theme = read(os.path.join(ROOT, "lua/pointshop/cl_theme.lua"))
    colours = set(re.findall(r"^T\.([A-Za-z0-9_]+)\s*=\s*Color", theme, re.M))

    problems = []
    for table in ("T.Selectable = {", "T.Action = {"):
        start = theme.index(table)
        block = theme[start:theme.index("\n}", start)]
        for m in re.finditer(r"=\s*T\.([A-Za-z0-9_]+)", block):
            if m.group(1) not in colours:
                problems.append(f"{table.rstrip(' ={')}: references T.{m.group(1)}, "
                                f"which is not a colour token")
    return problems


def check_concommands(files):
    """No two console commands share a name - the second silently replaces the first."""
    seen, problems = {}, []
    for path in files:
        for m in re.finditer(r'concommand\.Add\(\s*"([^"]+)"', read(path)):
            name = m.group(1)
            if name in seen:
                problems.append(f"{path}: console command '{name}' already registered in "
                                f"{seen[name]}")
            seen[name] = path
    return problems


def check_hooks(files):
    """No two hook.Add calls share an event AND an identifier - the second replaces the first."""
    seen, problems = {}, []
    for path in files:
        for m in re.finditer(r'hook\.Add\(\s*"([^"]+)"\s*,\s*"([^"]+)"', read(path)):
            key = (m.group(1), m.group(2))
            if key in seen:
                problems.append(f"{path}: hook {key[0]}/{key[1]} already added in {seen[key]}")
            seen[key] = path
    return problems


CHECKS = {
    "structure":    check_structure,
    "declarations": check_declarations,
    "paint":        check_paint_allocation,
    "seeding":      check_seeding,
    "members":      check_members,
    "palette":      check_palette,
    "metrics":      check_metrics_defined,
    "styles":       check_styles,
    "netstrings":   check_netstrings,
    "globals":      check_globals,
    "concommands":  check_concommands,
    "hooks":        check_hooks,
}


def main(argv):
    names = [a for a in argv if not a.startswith("-")]
    if "--files" in argv:
        files = argv[argv.index("--files") + 1:]
        names = [n for n in names if n not in files]
    else:
        files = sorted(glob.glob(os.path.join(ROOT, "lua/**/*.lua"), recursive=True))

    run = names or list(CHECKS)
    failed = 0

    for name in run:
        if name not in CHECKS:
            print(f"unknown check '{name}'; known: {', '.join(CHECKS)}")
            return 2

        problems = CHECKS[name](files)
        status = "ok" if not problems else f"{len(problems)} problem(s)"
        print(f"{name:13s} {status}")
        for p in problems:
            print(f"    {os.path.relpath(p.split(':')[0], ROOT) if p.startswith('/') else p}"
                  if False else f"    {p.replace(ROOT + os.sep, '')}")
        failed += len(problems)

    print(f"\n{'PASS' if not failed else f'FAIL - {failed} problem(s)'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
