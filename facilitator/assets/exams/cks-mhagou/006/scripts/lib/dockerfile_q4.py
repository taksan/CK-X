#!/usr/bin/env python3
"""Parse a Dockerfile into its instructions (line continuations and comments handled).

usage: dockerfile_q4.py FILE   -> JSON {"stages": [{"from": ..., "image": ..., "users": [...]}], "instructions": [[NAME, args], ...]}
"""
import json
import re
import sys


def instructions(text):
    logical, buf = [], ''
    for raw in text.splitlines():
        line = raw.rstrip()
        if not buf and (not line.strip() or line.lstrip().startswith('#')):
            continue
        if buf and line.lstrip().startswith('#'):
            continue
        if line.endswith('\\'):
            buf += line[:-1] + ' '
            continue
        buf += line
        logical.append(buf.strip())
        buf = ''
    if buf:
        logical.append(buf.strip())
    out = []
    for l in logical:
        m = re.match(r'(\S+)\s*(.*)$', l)
        if m:
            out.append([m.group(1).upper(), m.group(2)])
    return out


def main():
    ins = instructions(open(sys.argv[1]).read())
    stages = []
    for name, args in ins:
        if name == 'FROM':
            parts = [p for p in args.split() if not p.startswith('--')]
            stages.append({'from': args, 'image': parts[0] if parts else '', 'users': []})
        elif name == 'USER' and stages:
            stages[-1]['users'].append(args.split()[0].split(':')[0] if args.split() else '')
    print(json.dumps({'stages': stages, 'instructions': ins}))


if __name__ == '__main__':
    main()
