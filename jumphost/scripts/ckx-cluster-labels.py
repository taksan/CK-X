#!/usr/bin/env python3
"""ckx-cluster-labels: mark what the exam setups create in the cluster, and remove it later.

The setups of the exams create namespaces and other objects through the API of a cluster that can outlive
the exam (an external cluster). When an exam ends badly, or its cleanup is incomplete, those objects stay
and pile up. This tool makes them easy to find:

  ckx-cluster-labels snapshot FILE
      Records what exists now (call it before the setups).
  ckx-cluster-labels label FILE --exam LAB --run RUN
      Labels what exists now and is not in the snapshot (call it after the setups, also after a failed one):
          ck-x.io/created-by=ck-x-simulator
          ck-x.io/exam=<lab id of the exam, for example mhagou-008>
          ck-x.io/exam-run=<id of the run of the exam>
  ckx-cluster-labels sweep [--yes] [--wait SECONDS]
      Deletes everything that carries ck-x.io/created-by=ck-x-simulator, whichever exam created it
      (call it when an exam starts and when it ends). Without --yes it only prints what it would delete.

Safeguards (a wrong label must never be able to remove what the cluster itself runs):
  - an object is labelled only if it is not in the snapshot AND it was created after the snapshot was taken
    (the time is the one of the cluster), so a bad or old snapshot cannot select existing objects;
  - the snapshot must be complete (it holds the namespaces of the cluster), recent (6 hours) and of this cluster;
  - nothing is labelled in the system namespaces, nor an object managed by Helm; at most --max objects are labelled;
  - sweep never deletes the system namespaces (kube-*, default), nor anything in them, nor an object managed by
    Helm, and refuses to delete more than --max objects (it prints the list instead).

What is labelled: the objects that kubectl (or helm) created, that no other object owns, and that are not in a
namespace that is itself new (that namespace is labelled, and deleting it deletes its content). The objects that
controllers create by themselves (identities, endpoints, tokens ...) are left alone.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

CREATED_BY_KEY = "ck-x.io/created-by"
CREATED_BY = "ck-x-simulator"
SELECTOR = f"{CREATED_BY_KEY}={CREATED_BY}"

# never labelled nor deleted
SKIP = {
    "namespaces", "nodes", "apiservices.apiregistration.k8s.io", "events", "events.events.k8s.io",
    "endpoints", "endpointslices.discovery.k8s.io", "leases.coordination.k8s.io", "componentstatuses",
}
# managers of the objects that a setup creates
MANAGERS = ("kubectl",)
# never labelled nor deleted: the namespaces of the cluster itself, and what is in them
PROTECTED_NAMESPACES = {"default", "kube-system", "kube-public", "kube-node-lease"}
SNAPSHOT_VERSION = 2
SNAPSHOT_MAX_AGE = 6 * 3600
DEFAULT_MAX = 150


def log(message):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] [ckx-cluster-labels] {message}", flush=True)


def kubectl(*args, timeout=120):
    return subprocess.run(
        ["kubectl", "--request-timeout=60s", *args], capture_output=True, text=True, timeout=timeout
    )


def resource_types():
    """(namespaced, cluster-scoped) lists of the resource names that can be listed and deleted."""
    found = {}
    for namespaced in ("true", "false"):
        out = kubectl("api-resources", f"--namespaced={namespaced}", "--verbs=list,delete", "-o", "name").stdout
        found[namespaced] = [r for r in out.split() if r not in SKIP]
    return found["true"], found["false"]


def list_objects(resource, selector=None):
    """The objects of a resource (all namespaces), with their managed fields."""
    args = ["get", resource, "-A", "-o", "json", "--show-managed-fields", "--ignore-not-found"]
    if selector:
        args += ["-l", selector]
    result = kubectl(*args)
    try:
        return json.loads(result.stdout).get("items", [])
    except ValueError:
        return []


def list_all():
    """{resource: [object ...]} of every resource type, plus the namespaces."""
    namespaced, cluster = resource_types()
    resources = ["namespaces"] + namespaced + cluster
    with ThreadPoolExecutor(max_workers=8) as pool:
        return dict(zip(resources, pool.map(list_objects, resources)))


def managed_by_helm(obj):
    meta = obj.get("metadata", {})
    return (
        (meta.get("labels") or {}).get("app.kubernetes.io/managed-by") == "Helm"
        or "meta.helm.sh/release-name" in (meta.get("annotations") or {})
        or str(obj.get("type", "")).startswith("helm.sh/")
    )


def cluster_now():
    """The time of the cluster: the creation time that its API server gives to a (not stored) object."""
    result = kubectl("create", "namespace", "ckx-clock", "--dry-run=server", "-o", "jsonpath={.metadata.creationTimestamp}")
    stamp = result.stdout.strip()
    return stamp if result.returncode == 0 and stamp.endswith("Z") else None


def cluster_id():
    namespaces = list_objects("namespaces")
    return next((o["metadata"]["uid"] for o in namespaces if o["metadata"]["name"] == "kube-system"), None)


def created_by_a_setup(obj):
    meta = obj.get("metadata", {})
    if meta.get("ownerReferences") or managed_by_helm(obj) or meta.get("namespace") in PROTECTED_NAMESPACES:
        return False
    return any((f.get("manager") or "").startswith(MANAGERS) for f in meta.get("managedFields", []))


def uids(objects):
    return {o["metadata"]["uid"] for o in objects}


def cmd_snapshot(args):
    now, cluster = cluster_now(), cluster_id()
    if not now or not cluster:
        log("ERROR: cannot read the clock or the identity of the cluster: no snapshot taken")
        return 1
    objects = {resource: sorted(uids(items)) for resource, items in list_all().items()}
    if len(objects.get("namespaces", [])) < 4:
        log("ERROR: the snapshot does not hold the namespaces of the cluster: not saved")
        return 1
    with open(args.file, "w") as f:
        json.dump({"version": SNAPSHOT_VERSION, "cluster": cluster, "taken": now, "taken_at": time.time(), "objects": objects}, f)
    log(f"Snapshot of the cluster saved ({sum(len(v) for v in objects.values())} objects)")
    return 0


def cmd_label(args):
    try:
        with open(args.file) as f:
            snapshot = json.load(f)
    except (OSError, ValueError):
        log(f"No snapshot in {args.file}: nothing to label")
        return 0
    if snapshot.get("version") != SNAPSHOT_VERSION or len(snapshot.get("objects", {}).get("namespaces", [])) < 4:
        log("ERROR: the snapshot is not valid (old format or incomplete): nothing labelled")
        return 1
    if time.time() - snapshot.get("taken_at", 0) > SNAPSHOT_MAX_AGE:
        log("ERROR: the snapshot is too old: nothing labelled")
        return 1
    if snapshot.get("cluster") != cluster_id():
        log("ERROR: the snapshot is of another cluster: nothing labelled")
        return 1
    before = {resource: set(u) for resource, u in snapshot["objects"].items()}
    taken = snapshot["taken"]  # RFC 3339 UTC strings compare in time order

    labels = [f"{CREATED_BY_KEY}={CREATED_BY}", f"ck-x.io/exam={args.exam}", f"ck-x.io/exam-run={args.run}"]
    now = list_all()
    new_namespaces = {
        o["metadata"]["name"] for o in now.get("namespaces", []) if o["metadata"]["uid"] not in before.get("namespaces", set())
    }

    plan = []  # (resource, namespace, [names])
    for resource, objects in now.items():
        known = before.get(resource, set())
        by_namespace = {}
        for o in objects:
            meta = o["metadata"]
            if meta["uid"] in known or meta.get("creationTimestamp", "") < taken:
                continue
            if meta.get("name") in PROTECTED_NAMESPACES and resource == "namespaces":
                continue
            if not created_by_a_setup(o):
                continue
            namespace = meta.get("namespace")
            if namespace in new_namespaces:
                continue  # goes away with its namespace
            by_namespace.setdefault(namespace, []).append(meta["name"])
        plan += [(resource, namespace, names) for namespace, names in by_namespace.items()]
    total = sum(len(names) for _, _, names in plan)
    if total > args.max:
        log(f"ERROR: {total} objects would be labelled (more than {args.max}): nothing labelled")
        for resource, namespace, names in plan:
            log(f"  {resource} {' '.join(names)}" + (f" (namespace {namespace})" if namespace else ""))
        return 1

    labelled = 0
    for resource, namespace, names in plan:
        target = ["-n", namespace] if namespace else []
        result = kubectl("label", resource, *names, *target, *labels, "--overwrite")
        if result.returncode != 0:
            log(f"WARNING: could not label {resource} {' '.join(names)}: {result.stderr.strip()[:200]}")
            continue
        labelled += len(names)
        log(f"Labelled {resource}: {' '.join(names)}" + (f" (namespace {namespace})" if namespace else ""))
    log(f"Labelled {labelled} object(s) of exam {args.exam}")
    return 0


def deletable(o):
    meta = o["metadata"]
    return meta.get("namespace") not in PROTECTED_NAMESPACES and meta["name"] not in PROTECTED_NAMESPACES and not managed_by_helm(o)


def cmd_sweep(args):
    namespaces = [o["metadata"]["name"] for o in list_objects("namespaces", SELECTOR) if deletable(o)]

    # what would go: the namespaces, and the labelled objects that are not in them
    namespaced, cluster = resource_types()
    cluster.sort(key=lambda r: r.startswith("customresourcedefinitions"))  # their resources go with them
    found = []
    for resource in namespaced + cluster:
        found += [(resource, o["metadata"]) for o in list_objects(resource, SELECTOR) if deletable(o)
                  and o["metadata"].get("namespace") not in namespaces]
    total = len(namespaces) + len(found)
    if total > args.max:
        log(f"ERROR: {total} objects would be deleted (more than {args.max}): nothing deleted, check the cluster")
    if not args.yes or total > args.max:
        for namespace in namespaces:
            log(f"Would delete namespace {namespace}")
        for resource, meta in found:
            log(f"Would delete {resource} {meta['name']}" + (f" (namespace {meta['namespace']})" if meta.get("namespace") else ""))
        log(f"{total} object(s) from earlier exams" + ("" if args.yes else " (run with --yes to delete them)"))
        return 1 if total > args.max else 0

    if namespaces:
        log(f"Deleting the namespaces left by earlier exams: {' '.join(namespaces)}")
        for namespace in namespaces:
            kubectl("delete", "pods", "--all", "-n", namespace, "--force", "--grace-period=0", "--wait=false")
        kubectl("delete", "namespace", *namespaces, "--ignore-not-found", "--wait=false")

    for resource, meta in found:
        target = ["-n", meta["namespace"]] if meta.get("namespace") else []
        kubectl("delete", resource, meta["name"], *target, "--ignore-not-found", "--wait=false")
        log(f"Deleted {resource} {meta['name']}" + (f" (namespace {meta['namespace']})" if meta.get("namespace") else ""))

    deadline = time.time() + args.wait
    while namespaces and time.time() < deadline:
        namespaces = [o["metadata"]["name"] for o in list_objects("namespaces", SELECTOR) if deletable(o)]
        if namespaces:
            time.sleep(3)
    if namespaces:
        log(f"WARNING: still terminating after {args.wait} s: {' '.join(namespaces)}")
        return 1
    log("Nothing left from earlier exams")
    return 0


def main():
    if not os.environ.get("KUBECONFIG") and os.path.exists("/home/candidate/.kube/kubeconfig"):
        os.environ["KUBECONFIG"] = "/home/candidate/.kube/kubeconfig"

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("snapshot")
    p.add_argument("file")
    p = sub.add_parser("label")
    p.add_argument("file")
    p.add_argument("--exam", required=True)
    p.add_argument("--run", required=True)
    p.add_argument("--max", type=int, default=DEFAULT_MAX)
    p = sub.add_parser("sweep")
    p.add_argument("--yes", action="store_true", help="delete (without it, only print)")
    p.add_argument("--max", type=int, default=DEFAULT_MAX)
    p.add_argument("--wait", type=int, default=180)
    args = parser.parse_args()
    return {"snapshot": cmd_snapshot, "label": cmd_label, "sweep": cmd_sweep}[args.command](args) or 0


if __name__ == "__main__":
    sys.exit(main())
