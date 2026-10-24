#!/usr/bin/env python3
"""Check the Dockerfile of question 5 (parsed instruction by instruction, nothing is executed).

usage: dockerfile_q5.py <Dockerfile> <check>

checks: base | instructions | user | entrypoint
Prints the reason and exits 1 when the check fails.
"""
import json
import re
import sys


def parse(path):
    """Instructions as (OP, rest) with line continuations joined and comments dropped."""
    out, pending = [], ""
    with open(path) as f:
        for raw in f:
            line = raw.rstrip("\n").rstrip("\r")
            if not pending and (not line.strip() or line.lstrip().startswith("#")):
                continue
            if pending and line.lstrip().startswith("#"):
                continue
            if line.rstrip().endswith("\\"):
                pending += line.rstrip()[:-1] + " "
                continue
            text = (pending + line).strip()
            pending = ""
            if not text:
                continue
            op, _, rest = text.partition(" ")
            out.append((op.upper(), rest.strip()))
    return out


def main():
    ins = parse(sys.argv[1])
    check = sys.argv[2]

    if check == "base":
        froms = [r for o, r in ins if o == "FROM"]
        if len(froms) != 1:
            print("the Dockerfile must have exactly one FROM (found %d)" % len(froms))
            return 1
        parts = froms[0].split()
        parts = [p for p in parts if not p.startswith("--platform=")]
        image = parts[0] if parts else ""
        if not re.fullmatch(r"gcr\.io/distroless/base(:[A-Za-z0-9_.-]+)?(@sha256:[0-9a-f]{64})?", image) or ":debug" in image:
            print("the base image is '%s', expected gcr.io/distroless/base" % image)
            return 1
        if len(parts) > 1 and not (len(parts) == 3 and parts[1].upper() == "AS"):
            print("unexpected words after the base image: %s" % " ".join(parts[1:]))
            return 1
        return 0

    if check == "instructions":
        extra = [o for o, r in ins if o not in ("FROM", "COPY", "USER", "ENTRYPOINT")]
        if extra:
            print("unnecessary instructions remain: %s (only FROM, COPY, USER and ENTRYPOINT are needed)" % ", ".join(extra))
            return 1
        copies = [r for o, r in ins if o == "COPY"]
        if len(copies) != 1:
            print("expected exactly one COPY (found %d)" % len(copies))
            return 1
        rest = copies[0]
        while re.match(r"--(chmod|chown|link)(=\S+)?\s+", rest):
            rest = re.sub(r"^--\S+\s+", "", rest)
        if rest.startswith("["):
            try:
                args = json.loads(rest)
            except ValueError:
                print("the COPY instruction is not valid")
                return 1
        else:
            args = rest.split()
        args = [a.strip('"') for a in args]
        if len(args) != 2 or args[0] not in ("app-server", "./app-server") or args[1] != "/app/server":
            print("COPY must copy only app-server to /app/server (found: %s)" % " ".join(args))
            return 1
        return 0

    if check == "user":
        users = [r for o, r in ins if o == "USER"]
        if not users:
            print("there is no USER instruction: the container would run as root")
            return 1
        if not re.fullmatch(r"(nonroot|65532)(:(nonroot|65532))?", users[-1]):
            print("the last USER is '%s', expected nonroot / 65532" % users[-1])
            return 1
        return 0

    if check == "entrypoint":
        eps = [r for o, r in ins if o == "ENTRYPOINT"]
        if not eps:
            print("there is no ENTRYPOINT instruction")
            return 1
        try:
            val = json.loads(eps[-1])
        except ValueError:
            print("the ENTRYPOINT is in shell form (%s): use the exec form [\"/app/server\"]" % eps[-1])
            return 1
        if val != ["/app/server"]:
            print("the ENTRYPOINT is %s, expected [\"/app/server\"]" % json.dumps(val))
            return 1
        return 0

    print("unknown check")
    return 2


sys.exit(main())
