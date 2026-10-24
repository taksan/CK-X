#!/usr/bin/env python3
"""Question 14 helper: parse a Dockerfile (line continuations, comments) and run one check.

usage: dockerfile_q14.py FILE base|user|apt|kept
exit 0 = check passed; the first line printed names the failure (or the success)
"""
import re
import sys


def instructions(path):
    out, cur = [], ""
    with open(path) as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not cur and (not line.strip() or line.lstrip().startswith("#")):
                continue
            if line.lstrip().startswith("#"):
                continue
            if line.rstrip().endswith("\\"):
                cur += line.rstrip()[:-1] + " "
                continue
            cur += line
            out.append(cur.strip())
            cur = ""
    if cur.strip():
        out.append(cur.strip())
    return out


def main():
    path, check = sys.argv[1], sys.argv[2]
    try:
        ins = instructions(path)
    except OSError:
        print("❌ %s does not exist" % path)
        return 1
    kinds = [(i.split(None, 1)[0].upper(), i.split(None, 1)[1] if len(i.split(None, 1)) > 1 else "") for i in ins]

    if check == "base":
        froms = [a for k, a in kinds if k == "FROM"]
        if not froms:
            print("❌ The Dockerfile has no FROM instruction")
            return 1
        img = [t for t in froms[-1].split() if not t.startswith("--")][0]
        if "@sha256:" in img:
            print("✅ The base image is pinned by digest (%s)" % img)
            return 0
        name = img.rsplit("/", 1)[-1]
        if ":" not in name or name.rsplit(":", 1)[1] in ("latest", ""):
            print("❌ The base image '%s' is not pinned to a specific version" % img)
            return 1
        if not name.startswith("ubuntu:"):
            print("❌ The base image must stay ubuntu (a pinned version), found '%s'" % img)
            return 1
        print("✅ The base image is pinned (%s)" % img)
        return 0

    if check == "user":
        users = [a.split()[0] for k, a in kinds if k == "USER" and a.split()]
        if not users:
            print("❌ The Dockerfile has no USER instruction: the container runs as root")
            return 1
        last = users[-1].split(":")[0]
        if last in ("root", "0"):
            print("❌ The last USER instruction is '%s': the container still runs as root" % users[-1])
            return 1
        print("✅ The container runs as the unprivileged user %s" % users[-1])
        return 0

    if check == "apt":
        runs = [a for k, a in kinds if k == "RUN"]
        for r in runs:
            if re.search(r"\bapt\s+(get|update|install)\b", r):
                print("❌ 'apt get' / 'apt update' is not a valid command (use apt-get): %s" % r[:60])
                return 1
        updates = [r for r in runs if re.search(r"apt-get\s+update", r)]
        installs = [r for r in runs if re.search(r"apt-get\s+install", r)]
        if not updates or not installs:
            print("❌ The Dockerfile must still update the package index and install wget and curl with apt-get")
            return 1
        both = [r for r in runs if re.search(r"apt-get\s+update", r) and re.search(r"apt-get\s+install", r)]
        if not both:
            print("❌ apt-get update and apt-get install must be in the same RUN instruction (a cached update layer gives outdated packages)")
            return 1
        text = " ".join(installs)
        if "wget" not in text or "curl" not in text:
            print("❌ wget and curl must still be installed")
            return 1
        print("✅ apt-get update and install run in one RUN instruction and install wget and curl")
        return 0

    if check == "kept":
        want = [("WORKDIR", "/code"), ("COPY", "package.json"), ("RUN", "npm ci"), ("COPY", "src"), ("CMD", "npm")]
        for k, frag in want:
            if not any(kk == k and frag in a for kk, a in kinds):
                print("❌ The instruction '%s ... %s' of the original Dockerfile was removed or changed" % (k, frag))
                return 1
        print("✅ The other instructions of the Dockerfile were kept")
        return 0

    print("unknown check")
    return 2


if __name__ == "__main__":
    sys.exit(main())
