#!/usr/bin/env python3
# Question 11: parses the Dockerfile of the candidate. Usage: dockerfile_q11.py CHECK FILE
# CHECK: base | user | rest. Exit 0 when the check passes; the first output line is the failure reason.
import re, shlex, sys

def instructions(text):
    result, pending = [], ""
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        line = line.rstrip()
        if line.endswith("\\"):
            pending += line[:-1] + " "
            continue
        line = pending + line
        pending = ""
        parts = line.strip().split(None, 1)
        if len(parts) != 2:
            raise ValueError("an instruction has no argument: " + line)
        result.append((parts[0].upper(), parts[1].strip()))
    if pending:
        raise ValueError("unterminated line continuation")
    return result

def base_ok(ins):
    base = [a for op, a in ins if op == "FROM"]
    if len(base) != 1:
        return False, "the Dockerfile must have exactly one FROM"
    try:
        parts = shlex.split(base[0])
    except ValueError:
        return False, "the FROM line cannot be parsed"
    if len(parts) != 1:
        return False, "the FROM line has options or an alias; keep it as 'FROM ubuntu:<tag>'"
    m = re.fullmatch(r"(?:docker\.io/(?:library/)?|library/)?ubuntu(?::([A-Za-z0-9_][A-Za-z0-9_.-]*))?(?:@sha256:([a-fA-F0-9]{64}))?", parts[0])
    if not m:
        return False, "the base image is '%s': it must stay ubuntu" % parts[0]
    if m.group(2) or (m.group(1) and m.group(1).lower() not in ("latest", "rolling", "devel")):
        return True, ""
    return False, "the base image '%s' is not pinned to an explicit release tag or digest" % parts[0]

def user_ok(ins):
    users = [a for op, a in ins if op == "USER"]
    if len(users) != 1:
        return False, "the Dockerfile must have exactly one USER instruction (found %d)" % len(users)
    f = shlex.split(users[0])
    if len(f) == 1 and re.fullmatch(r"(?:test-user|5487)(?::[A-Za-z0-9_.-]+)?", f[0]):
        return True, ""
    return False, "the user is '%s', expected test-user (UID 5487)" % users[0]

def rest_ok(ins):
    expected = [("FROM", None), ("RUN", "apt-get update -y"), ("RUN", "apt-install nginx -y"), ("COPY", "entrypoint.sh /"),
                ("ENTRYPOINT", "['/entrypoint.sh']"), ("USER", None)]
    if len(ins) != len(expected):
        return False, "instructions were added or removed (%d instructions, expected %d)" % (len(ins), len(expected))
    for (op, arg), (eop, earg) in zip(ins, expected):
        if op != eop:
            return False, "the order or kind of the instructions changed (%s instead of %s)" % (op, eop)
        if earg is not None and shlex.split(arg) != shlex.split(earg):
            return False, "the instruction '%s %s' was modified" % (op, arg)
    return True, ""

check, path = sys.argv[1], sys.argv[2]
try:
    ins = instructions(open(path).read())
except (OSError, ValueError) as exc:
    print("the Dockerfile cannot be read: %s" % exc)
    sys.exit(1)

if check == "base":
    ok, why = base_ok(ins)
elif check == "user":
    ok, why = user_ok(ins)
else:
    b, bw = base_ok(ins)
    u, uw = user_ok(ins)
    if not (b and u):
        print("not credited yet: fix the base image and the user first")
        sys.exit(1)
    ok, why = rest_ok(ins)
if not ok:
    print(why)
    sys.exit(1)
sys.exit(0)
