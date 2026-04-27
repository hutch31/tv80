#!/usr/bin/env python3
"""Minimal VCD debugging extractor for agent-oriented waveform triage.

Features:
- List signals by name/glob
- Extract selected signals into timeline/csv/jsonl
- Trigger scan with optional pre/post windows
- Summarize toggles and unknown-state activity
"""

from __future__ import annotations

import argparse
import ast
import csv
import fnmatch
import json
import re
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Iterable, Iterator, List, Optional, Set, Tuple


@dataclass(frozen=True)
class SignalDef:
    id_code: str
    ref: str
    full_name: str
    width: int


PROFILES: Dict[str, List[str]] = {
    "fetch-cycle-controls": ["m1_n", "mreq_n", "iorq_n", "rd_n", "wr_n", "A"],
    "interrupt-debug": ["int_n", "nmi_n", "iff*", "im*"],
}


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="VCD signal extraction and debugging helper")
    sub = p.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list-signals", help="List available signals")
    p_list.add_argument("vcd", nargs="?", default="dump.vcd", help="Path to VCD file")
    p_list.add_argument("--match", action="append", default=[], help="Glob pattern(s) to filter signals")
    p_list.add_argument("--ids", action="store_true", help="Print VCD id codes")
    p_list.set_defaults(func=cmd_list_signals)

    p_extract = sub.add_parser("extract", help="Extract selected signals")
    add_common_selection_args(p_extract)
    p_extract.add_argument("--from-ts", type=int, default=None, help="Start timestamp (inclusive)")
    p_extract.add_argument("--to-ts", type=int, default=None, help="End timestamp (inclusive)")
    p_extract.add_argument("--changed-only", action="store_true", help="Emit only timestamps with selected signal changes")
    p_extract.add_argument("--condition", default=None, help="Filter expression over selected signals")
    p_extract.add_argument("--format", choices=["timeline", "csv", "jsonl"], default="timeline", help="Output format")
    p_extract.add_argument("--output", default=None, help="Output file path (default stdout)")
    p_extract.set_defaults(func=cmd_extract)

    p_trig = sub.add_parser("trigger-scan", help="Scan for trigger condition hits")
    add_common_selection_args(p_trig)
    p_trig.add_argument("--trigger", required=True, help="Trigger expression over selected signals")
    p_trig.add_argument("--edge", choices=["level", "rising", "falling"], default="rising", help="Trigger mode")
    p_trig.add_argument("--pre", type=int, default=2, help="Events before hit to print")
    p_trig.add_argument("--post", type=int, default=2, help="Events after hit to print")
    p_trig.add_argument("--from-ts", type=int, default=None, help="Start timestamp (inclusive)")
    p_trig.add_argument("--to-ts", type=int, default=None, help="End timestamp (inclusive)")
    p_trig.set_defaults(func=cmd_trigger_scan)

    p_sum = sub.add_parser("summarize", help="Summarize signal activity")
    add_common_selection_args(p_sum)
    p_sum.add_argument("--from-ts", type=int, default=None, help="Start timestamp (inclusive)")
    p_sum.add_argument("--to-ts", type=int, default=None, help="End timestamp (inclusive)")
    p_sum.set_defaults(func=cmd_summarize)

    return p


def add_common_selection_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("vcd", nargs="?", default="dump.vcd", help="Path to VCD file")
    p.add_argument("--signal", action="append", default=[], help="Signal or glob pattern (repeatable)")
    p.add_argument("--signals-file", default=None, help="Path to file with one signal/glob pattern per line")
    p.add_argument("--profile", choices=sorted(PROFILES.keys()), default=None, help="Built-in signal selection profile")


def parse_header(vcd_path: Path) -> List[SignalDef]:
    signals: List[SignalDef] = []
    scope_stack: List[str] = []

    with vcd_path.open("r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$scope"):
                parts = line.split()
                if len(parts) >= 3:
                    scope_stack.append(parts[2])
                continue
            if line.startswith("$upscope"):
                if scope_stack:
                    scope_stack.pop()
                continue
            if line.startswith("$var"):
                parts = line.split()
                if len(parts) >= 5:
                    width = int(parts[2])
                    id_code = parts[3]
                    ref = parts[4]
                    full_name = ".".join(scope_stack + [ref]) if scope_stack else ref
                    signals.append(SignalDef(id_code=id_code, ref=ref, full_name=full_name, width=width))
                continue
            if line.startswith("$enddefinitions"):
                break
    return signals


def load_patterns(args: argparse.Namespace) -> List[str]:
    patterns: List[str] = []
    patterns.extend(args.signal or [])
    if args.profile:
        patterns.extend(PROFILES[args.profile])

    if args.signals_file:
        with Path(args.signals_file).open("r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                patterns.append(line)
    return patterns


def match_signal(sig: SignalDef, pattern: str) -> bool:
    if fnmatch.fnmatch(sig.full_name, pattern):
        return True
    if fnmatch.fnmatch(sig.ref, pattern):
        return True
    if sig.full_name == pattern:
        return True
    return sig.full_name.endswith("." + pattern)


def select_signals(all_signals: List[SignalDef], patterns: List[str]) -> List[SignalDef]:
    if not patterns:
        return []
    selected: List[SignalDef] = []
    seen: Set[str] = set()
    for sig in all_signals:
        if any(match_signal(sig, pat) for pat in patterns):
            if sig.id_code not in seen:
                selected.append(sig)
                seen.add(sig.id_code)
    return selected


def parse_vcd_changes(
    vcd_path: Path,
    tracked_ids: Set[str],
) -> Iterator[Tuple[int, Set[str], Dict[str, str]]]:
    """Yield (timestamp, changed_id_codes, current_state_for_tracked_ids)."""
    state: Dict[str, str] = {}
    changed_in_ts: Set[str] = set()
    ts = 0
    in_header = True

    def flush() -> Optional[Tuple[int, Set[str], Dict[str, str]]]:
        if not changed_in_ts:
            return None
        return ts, set(changed_in_ts), dict(state)

    with vcd_path.open("r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue

            if in_header:
                if line.startswith("$enddefinitions"):
                    in_header = False
                continue

            if line.startswith("#"):
                pending = flush()
                if pending is not None:
                    yield pending
                changed_in_ts.clear()
                ts = int(line[1:])
                continue

            if line.startswith("$"):
                continue

            value: Optional[str] = None
            sig_id: Optional[str] = None

            if line[0] in ("b", "B", "r", "R"):
                parts = line.split()
                if len(parts) == 2:
                    value = parts[0][1:]
                    sig_id = parts[1]
            else:
                value = line[0]
                sig_id = line[1:]

            if sig_id is None or value is None:
                continue
            if sig_id not in tracked_ids:
                continue

            if state.get(sig_id) != value:
                state[sig_id] = value
                changed_in_ts.add(sig_id)

    pending = flush()
    if pending is not None:
        yield pending


def normalize_name(name: str) -> str:
    n = re.sub(r"[^A-Za-z0-9_]", "_", name)
    if not n:
        n = "sig"
    if n[0].isdigit():
        n = "s_" + n
    return n


def bit_value_to_python(value: str) -> Optional[int]:
    if not value:
        return None
    v = value.lower()
    if any(ch in v for ch in ("x", "z")):
        return None
    if re.fullmatch(r"[01]+", v):
        return int(v, 2)
    if v in ("0", "1"):
        return int(v)
    return None


def compile_condition(expr: Optional[str], selected: List[SignalDef]) -> Optional[Callable[[Dict[str, str]], bool]]:
    if not expr:
        return None

    allowed_nodes = (
        ast.Expression,
        ast.BoolOp,
        ast.BinOp,
        ast.UnaryOp,
        ast.Compare,
        ast.Name,
        ast.Load,
        ast.Constant,
        ast.And,
        ast.Or,
        ast.Not,
        ast.Eq,
        ast.NotEq,
        ast.Lt,
        ast.LtE,
        ast.Gt,
        ast.GtE,
        ast.BitAnd,
        ast.BitOr,
        ast.BitXor,
        ast.Add,
        ast.Sub,
        ast.Mult,
        ast.FloorDiv,
        ast.Mod,
        ast.USub,
        ast.UAdd,
    )

    tree = ast.parse(expr, mode="eval")
    for node in ast.walk(tree):
        if not isinstance(node, allowed_nodes):
            raise ValueError(f"Unsupported expression element: {type(node).__name__}")

    alias_to_sig: Dict[str, SignalDef] = {}
    for sig in selected:
        alias_to_sig.setdefault(normalize_name(sig.ref), sig)
        alias_to_sig.setdefault(normalize_name(sig.full_name), sig)

    code = compile(tree, "<condition>", "eval")

    def _eval(state: Dict[str, str]) -> bool:
        env: Dict[str, Optional[int]] = {}
        for alias, sig in alias_to_sig.items():
            env[alias] = bit_value_to_python(state.get(sig.id_code, ""))
        return bool(eval(code, {"__builtins__": {}}, env))

    return _eval


def event_rows(
    vcd_path: Path,
    selected: List[SignalDef],
    from_ts: Optional[int],
    to_ts: Optional[int],
    changed_only: bool,
    condition: Optional[Callable[[Dict[str, str]], bool]],
) -> Iterator[Tuple[int, List[str], Dict[str, str], Set[str]]]:
    tracked_ids = {s.id_code for s in selected}
    id_to_sig = {s.id_code: s for s in selected}

    for ts, changed_ids, state in parse_vcd_changes(vcd_path, tracked_ids):
        if from_ts is not None and ts < from_ts:
            continue
        if to_ts is not None and ts > to_ts:
            continue
        if changed_only and not changed_ids:
            continue
        if condition is not None and not condition(state):
            continue

        snapshot: Dict[str, str] = {}
        for sig in selected:
            snapshot[sig.full_name] = state.get(sig.id_code, "x" * max(1, sig.width))

        changed_names = sorted(id_to_sig[sid].full_name for sid in changed_ids if sid in id_to_sig)
        yield ts, changed_names, snapshot, changed_ids


def write_rows(
    rows: Iterable[Tuple[int, List[str], Dict[str, str], Set[str]]],
    fmt: str,
    selected: List[SignalDef],
    out,
) -> int:
    count = 0
    if fmt == "timeline":
        for ts, changed_names, snapshot, _changed_ids in rows:
            out.write(f"@{ts} changed={','.join(changed_names)}\n")
            for sig in selected:
                out.write(f"  {sig.full_name}={snapshot[sig.full_name]}\n")
            count += 1
        return count

    if fmt == "csv":
        writer = csv.writer(out)
        headers = ["timestamp", "changed"] + [s.full_name for s in selected]
        writer.writerow(headers)
        for ts, changed_names, snapshot, _changed_ids in rows:
            writer.writerow([ts, "|".join(changed_names)] + [snapshot[s.full_name] for s in selected])
            count += 1
        return count

    if fmt == "jsonl":
        for ts, changed_names, snapshot, _changed_ids in rows:
            out.write(json.dumps({"timestamp": ts, "changed": changed_names, "signals": snapshot}) + "\n")
            count += 1
        return count

    raise ValueError(f"Unsupported output format: {fmt}")


def cmd_list_signals(args: argparse.Namespace) -> int:
    vcd = Path(args.vcd)
    signals = parse_header(vcd)
    pats = args.match or []

    for sig in signals:
        if pats and not any(match_signal(sig, p) for p in pats):
            continue
        if args.ids:
            print(f"{sig.id_code:>4}  [{sig.width:>3}]  {sig.full_name}")
        else:
            print(sig.full_name)
    return 0


def cmd_extract(args: argparse.Namespace) -> int:
    vcd = Path(args.vcd)
    all_signals = parse_header(vcd)
    patterns = load_patterns(args)
    if not patterns:
        print("error: at least one --signal, --signals-file, or --profile is required", file=sys.stderr)
        return 2

    selected = select_signals(all_signals, patterns)
    if not selected:
        print("error: no signals matched the provided patterns", file=sys.stderr)
        return 2

    cond = compile_condition(args.condition, selected)
    rows = event_rows(
        vcd_path=vcd,
        selected=selected,
        from_ts=args.from_ts,
        to_ts=args.to_ts,
        changed_only=args.changed_only,
        condition=cond,
    )

    if args.output:
        with Path(args.output).open("w", encoding="utf-8", newline="") as out:
            count = write_rows(rows, args.format, selected, out)
    else:
        count = write_rows(rows, args.format, selected, sys.stdout)

    print(f"rows={count}", file=sys.stderr)
    return 0


def cmd_trigger_scan(args: argparse.Namespace) -> int:
    vcd = Path(args.vcd)
    all_signals = parse_header(vcd)
    patterns = load_patterns(args)
    if not patterns:
        print("error: at least one --signal, --signals-file, or --profile is required", file=sys.stderr)
        return 2

    selected = select_signals(all_signals, patterns)
    if not selected:
        print("error: no signals matched the provided patterns", file=sys.stderr)
        return 2

    trig = compile_condition(args.trigger, selected)
    if trig is None:
        print("error: --trigger is required", file=sys.stderr)
        return 2

    rows = list(
        event_rows(
            vcd_path=vcd,
            selected=selected,
            from_ts=args.from_ts,
            to_ts=args.to_ts,
            changed_only=True,
            condition=None,
        )
    )

    pre_buf: deque[Tuple[int, List[str], Dict[str, str], Set[str]]] = deque(maxlen=max(args.pre, 0))
    hit_count = 0
    prev_trig: Optional[bool] = None

    i = 0
    while i < len(rows):
        row = rows[i]
        ts, _changed, snapshot, _changed_ids = row

        state_by_id = {s.id_code: snapshot[s.full_name] for s in selected}
        cur = bool(trig(state_by_id))
        fired = False
        if args.edge == "level":
            fired = cur
        elif args.edge == "rising":
            fired = cur and (prev_trig is False or prev_trig is None)
        elif args.edge == "falling":
            fired = (not cur) and (prev_trig is True)

        if fired:
            hit_count += 1
            print(f"HIT {hit_count} at @{ts}")
            for pts, _pc, psnap, _pid in list(pre_buf):
                print(f"  PRE  @{pts} " + " ".join(f"{s.ref}={psnap[s.full_name]}" for s in selected))
            print(f"  CUR  @{ts} " + " ".join(f"{s.ref}={snapshot[s.full_name]}" for s in selected))
            for j in range(1, max(args.post, 0) + 1):
                if i + j >= len(rows):
                    break
                nts, _nc, nsnap, _nid = rows[i + j]
                print(f"  POST @{nts} " + " ".join(f"{s.ref}={nsnap[s.full_name]}" for s in selected))

        pre_buf.append(row)
        prev_trig = cur
        i += 1

    print(f"trigger_hits={hit_count}")
    return 0


def cmd_summarize(args: argparse.Namespace) -> int:
    vcd = Path(args.vcd)
    all_signals = parse_header(vcd)
    patterns = load_patterns(args)
    if not patterns:
        print("error: at least one --signal, --signals-file, or --profile is required", file=sys.stderr)
        return 2

    selected = select_signals(all_signals, patterns)
    if not selected:
        print("error: no signals matched the provided patterns", file=sys.stderr)
        return 2

    toggles = {s.full_name: 0 for s in selected}
    unknown_events = {s.full_name: 0 for s in selected}
    first_ts: Optional[int] = None
    last_ts: Optional[int] = None
    event_count = 0

    id_to_sig = {s.id_code: s for s in selected}

    for ts, changed_ids, state in parse_vcd_changes(vcd, set(id_to_sig.keys())):
        if args.from_ts is not None and ts < args.from_ts:
            continue
        if args.to_ts is not None and ts > args.to_ts:
            continue

        event_count += 1
        if first_ts is None:
            first_ts = ts
        last_ts = ts

        for sid in changed_ids:
            sig = id_to_sig.get(sid)
            if sig is None:
                continue
            toggles[sig.full_name] += 1

        for sig in selected:
            val = state.get(sig.id_code, "")
            if "x" in val.lower() or "z" in val.lower():
                unknown_events[sig.full_name] += 1

    print(f"events={event_count}")
    print(f"first_timestamp={first_ts}")
    print(f"last_timestamp={last_ts}")
    for sig in selected:
        print(
            f"{sig.full_name}: width={sig.width} toggles={toggles[sig.full_name]} unknown_events={unknown_events[sig.full_name]}"
        )

    return 0


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
