#!/usr/bin/env python3
"""Evaluate the egress rules of the NetworkPolicy of question 3 for sample destinations.

usage: netpol_q3.py <policy.json> <check>

checks
  select    the policy selects every Pod, restricts Egress and not Ingress
  dns       DNS (UDP and TCP 53) is allowed to any destination, malicious ranges included
  cidrs     the two malicious /24 ranges are denied on every other port, every other
            destination stays reachable on every port
Prints the reason and exits 1 when a check fails; exits 0 otherwise.
"""
import ipaddress
import json
import sys

BLOCKED = ["192.168.100.0/24", "10.0.99.0/24"]


def allowed(policy, ip, port, proto):
    """Is egress to ip:port/proto allowed by the egress rules of the policy (external address)?"""
    addr = ipaddress.ip_address(ip)
    for rule in policy.get("spec", {}).get("egress") or []:
        ports = rule.get("ports") or []
        if ports:
            ok = False
            for p in ports:
                if (p.get("protocol") or "TCP") != proto:
                    continue
                number = p.get("port")
                end = p.get("endPort")
                if isinstance(number, int) and (number == port or (end is not None and number <= port <= end)):
                    ok = True
                    break
            if not ok:
                continue
        peers = rule.get("to") or []
        if not peers:
            return True
        for peer in peers:
            block = peer.get("ipBlock")
            if not block:
                continue  # Pod and namespace selectors never match an external address
            net = ipaddress.ip_network(block["cidr"], strict=False)
            if addr.version != net.version or addr not in net:
                continue
            if any(addr in ipaddress.ip_network(e, strict=False) for e in block.get("except") or []):
                continue
            return True
    return False


def main():
    with open(sys.argv[1]) as f:
        policy = json.load(f)
    check = sys.argv[2]
    spec = policy.get("spec", {})

    if check == "select":
        selector = spec.get("podSelector")
        if not isinstance(selector, dict) or selector.get("matchLabels") or selector.get("matchExpressions"):
            print("the policy does not select all the Pods of the namespace (podSelector must be empty)")
            return 1
        types = spec.get("policyTypes") or []
        if "Egress" not in types:
            print("the policy does not restrict Egress (policyTypes: %s)" % types)
            return 1
        if "Ingress" in types or spec.get("ingress"):
            print("the policy also restricts Ingress: it must not be affected")
            return 1
        return 0

    if "Egress" not in (spec.get("policyTypes") or []):
        print("the policy does not restrict Egress")
        return 1

    if check == "dns":
        for ip in ["192.168.100.10", "10.0.99.10", "8.8.8.8", "10.96.0.10"]:
            for proto in ("UDP", "TCP"):
                if not allowed(policy, ip, 53, proto):
                    print("DNS %s/53 to %s is not allowed" % (proto, ip))
                    return 1
        return 0

    if check == "cidrs":
        for ip in ["192.168.100.1", "192.168.100.254", "10.0.99.1", "10.0.99.200"]:
            for port in (80, 443, 8080, 22, 5432):
                if allowed(policy, ip, port, "TCP"):
                    print("egress to %s:%d (TCP) is still allowed: it belongs to a malicious range" % (ip, port))
                    return 1
        for ip in ["8.8.8.8", "1.1.1.1", "10.0.1.1", "10.0.98.1", "10.0.100.1", "192.168.99.5", "192.168.101.1", "192.168.0.1", "172.16.5.5"]:
            for port in (80, 443, 8080, 22):
                if not allowed(policy, ip, port, "TCP"):
                    print("egress to %s:%d (TCP) is denied: only the malicious ranges must be blocked" % (ip, port))
                    return 1
        return 0

    print("unknown check")
    return 2


sys.exit(main())
