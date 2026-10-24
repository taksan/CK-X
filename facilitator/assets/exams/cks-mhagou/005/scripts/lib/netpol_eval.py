#!/usr/bin/env python3
"""Evaluate the egress rules of the NetworkPolicies of a namespace for one Pod, with the
semantics of the Kubernetes NetworkPolicy API (the union of the policies that select the Pod).

usage: netpol_eval.py <policies.json> <pod.json> <ip> <port> <proto>

<policies.json>  output of `kubectl get networkpolicy -n NS -o json`
<pod.json>       output of `kubectl get pod NAME -n NS -o json`
Only EXTERNAL destinations are evaluated (IP addresses outside the cluster): the Pod and
namespace selectors of a rule never match them, only an empty `to` (or no `to`) and an
ipBlock do.

Exit status: 0 = egress allowed, 1 = egress denied. The reason goes to stdout.
"""
import ipaddress
import json
import sys


def selector_matches(selector, labels):
    """LabelSelector against a dict of labels (None or {} selects everything)."""
    if not selector:
        return True
    for k, v in (selector.get("matchLabels") or {}).items():
        if labels.get(k) != v:
            return False
    for expr in selector.get("matchExpressions") or []:
        key, op, values = expr.get("key"), expr.get("operator"), expr.get("values") or []
        have = key in labels
        if op == "In" and not (have and labels[key] in values):
            return False
        if op == "NotIn" and have and labels[key] in values:
            return False
        if op == "Exists" and not have:
            return False
        if op == "DoesNotExist" and have:
            return False
    return True


def policy_types(policy):
    spec = policy.get("spec", {})
    types = spec.get("policyTypes")
    if types:
        return set(types)
    out = {"Ingress"}
    if spec.get("egress"):
        out.add("Egress")
    return out


def port_matches(ports, port, proto):
    if not ports:
        return True
    for p in ports:
        if (p.get("protocol") or "TCP") != proto:
            continue
        number = p.get("port")
        if number is None:
            return True
        if isinstance(number, int):
            end = p.get("endPort")
            if number == port or (end is not None and number <= port <= end):
                return True
    return False


def peer_matches_external(peer, addr):
    block = peer.get("ipBlock")
    if not block:
        return False
    net = ipaddress.ip_network(block["cidr"], strict=False)
    if addr.version != net.version or addr not in net:
        return False
    for e in block.get("except") or []:
        if addr in ipaddress.ip_network(e, strict=False):
            return False
    return True


def main():
    with open(sys.argv[1]) as f:
        policies = json.load(f).get("items", [])
    with open(sys.argv[2]) as f:
        pod = json.load(f)
    addr = ipaddress.ip_address(sys.argv[3])
    port = int(sys.argv[4])
    proto = sys.argv[5].upper()
    labels = pod.get("metadata", {}).get("labels") or {}

    selecting = [p for p in policies
                 if "Egress" in policy_types(p)
                 and selector_matches(p.get("spec", {}).get("podSelector"), labels)]
    if not selecting:
        print("no policy restricts the egress of the Pod: everything is allowed")
        return 0
    for policy in selecting:
        for rule in policy.get("spec", {}).get("egress") or []:
            if not port_matches(rule.get("ports"), port, proto):
                continue
            peers = rule.get("to") or []
            if not peers:
                print("allowed by %s (a rule without destination)" % policy["metadata"]["name"])
                return 0
            for peer in peers:
                if peer_matches_external(peer, addr):
                    print("allowed by %s (ipBlock)" % policy["metadata"]["name"])
                    return 0
    print("denied: no rule of %s allows %s:%d/%s" % (", ".join(p["metadata"]["name"] for p in selecting), addr, port, proto))
    return 1


sys.exit(main())
