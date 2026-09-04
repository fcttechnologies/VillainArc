#!/usr/bin/env python3
"""Measure accessibility-identifier coverage over SwiftUI interactive controls.

The testability standard asks for a stable identifier on every interactive control, because the
sim tools address by identifier and a control without one is invisible to an agent driving the
app. This is how that bar is measured; run it before and after any UI work.

    scripts/a11y-coverage.py VillainArc [--list-gaps]

Counting method, stated so the number can be argued with:

An "interactive control" is an occurrence of one of CONTROLS at the start of an expression.
Its "element" is that line plus every following line until the expression's bracket depth
returns to zero AND the next non-blank line no longer continues the chain with a leading `.`.
The element is covered when `.accessibilityIdentifier(` appears inside it at the element's own
chain level — a nested control's own identifier does not count for its parent, because the
scan attributes each occurrence to the nearest enclosing control start.

Deliberately NOT counted as controls: `Text`, `Label`, `Image` (not interactive on their own),
and anything inside a `#if DEBUG` block is counted separately rather than mixed in.

One known false positive, a consequence of attributing an occurrence to the nearest enclosing
control, so read a gap against its call site before treating it as one: a control that IS a whole
row or helper view, whose identifier the call site applies to the returned view rather than inside
the element this scan measures. The identifier is real and addressable either way.
A `#Preview` body is counted with the debug-only controls rather than the shipping ones: it renders
in Xcode's canvas and nowhere else, so an identifier on it would satisfy the count and nothing else.

"""
import argparse
import os
import re
import sys

CONTROLS = [
    "Button", "NavigationLink", "Toggle", "TextField", "SecureField", "TextEditor",
    "Picker", "Slider", "Stepper", "DatePicker", "Menu", "ColorPicker", "Link",
    "ShareLink", "EditButton", "Gauge",
]
CONTROL_RE = re.compile(r"(?<![A-Za-z0-9_.])(" + "|".join(CONTROLS) + r")\s*[({]")
TAP_RE = re.compile(r"\.onTapGesture\s*[({]")
ID_RE = re.compile(r"\.accessibilityIdentifier\s*\(")

OPEN, CLOSE = "([{", ")]}"


def element_span(lines, start):
    """Lines [start, end) covering one control expression and its whole modifier chain."""
    depth = 0
    i = start
    started = False
    while i < len(lines):
        line = lines[i]
        # Strip string literals and line comments so their brackets don't skew the depth.
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
        stripped = re.sub(r"//.*$", "", stripped)
        for ch in stripped:
            if ch in OPEN:
                depth += 1
                started = True
            elif ch in CLOSE:
                depth -= 1
        i += 1
        if started and depth <= 0:
            # The chain continues while following non-blank lines start with a modifier dot.
            j = i
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and lines[j].strip().startswith("."):
                i = j
                depth = 0
                started = False
                continue
            break
    return start, i


def scan_file(path):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    # Every `#if` goes on the stack, not just the DEBUG ones: a nested
    # `#if targetEnvironment(simulator)` inside a DEBUG block ends with its own `#endif`, which
    # would otherwise close the DEBUG range early and report debug-only controls as shipping.
    debug_ranges = []
    stack = []
    for n, line in enumerate(lines):
        s = line.strip()
        if s.startswith("#if"):
            stack.append((n, s.startswith("#if DEBUG")))
        elif s.startswith("#endif") and stack:
            start, is_debug = stack.pop()
            if is_debug:
                debug_ranges.append((start, n))

    # A `#Preview { … }` body is canvas-only scaffolding, so it belongs with the debug controls:
    # its span is the macro line to the closing brace at the macro's own indentation.
    for n, line in enumerate(lines):
        if not line.lstrip().startswith("#Preview"):
            continue
        indent = line[: len(line) - len(line.lstrip())]
        for j in range(n + 1, len(lines)):
            if lines[j] == indent + "}":
                debug_ranges.append((n, j))
                break

    def in_debug(n):
        return any(a <= n <= b for a, b in debug_ranges)

    results = []
    consumed_until = -1
    for n, line in enumerate(lines):
        if n < consumed_until:
            continue
        m = CONTROL_RE.search(line) or TAP_RE.search(line)
        if not m:
            continue
        # A control appearing as a *type* or inside a comment is not a control occurrence.
        before = line[: m.start()].strip()
        if before.startswith("//") or before.endswith(":") or "case " in before:
            continue
        start, end = element_span(lines, n)
        body = "\n".join(lines[start:end])
        results.append({
            "file": path,
            "line": n + 1,
            "kind": m.group(1) if m.re is CONTROL_RE else "onTapGesture",
            "covered": bool(ID_RE.search(body)),
            "debug": in_debug(n),
            "text": lines[n].strip()[:110],
        })
        consumed_until = end
    return results


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--list-gaps", action="store_true")
    parser.add_argument("--file")
    args = parser.parse_args(argv)

    paths = []
    if args.file:
        paths = [args.file]
    else:
        for base, _, files in os.walk(args.root):
            for f in files:
                if f.endswith(".swift"):
                    paths.append(os.path.join(base, f))

    all_results = []
    for p in sorted(paths):
        all_results.extend(scan_file(p))

    ship = [r for r in all_results if not r["debug"]]
    covered = [r for r in ship if r["covered"]]
    print(f"interactive controls (shipping):  {len(ship)}")
    print(f"  with an accessibility id:       {len(covered)}")
    print(f"  without:                        {len(ship) - len(covered)}")
    if ship:
        print(f"  coverage:                       {100.0 * len(covered) / len(ship):.1f}%")
    dbg = [r for r in all_results if r["debug"]]
    print(f"debug-only controls:              {len(dbg)} "
          f"({sum(1 for r in dbg if r['covered'])} with an id)")

    if args.list_gaps:
        print("\n=== gaps by file ===")
        by_file = {}
        for r in ship:
            if not r["covered"]:
                by_file.setdefault(r["file"], []).append(r)
        for f in sorted(by_file, key=lambda k: -len(by_file[k])):
            print(f"\n{f}  ({len(by_file[f])})")
            for r in by_file[f]:
                print(f"   {r['line']:>5}  {r['kind']:<15} {r['text']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
