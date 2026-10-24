#!/usr/bin/env python3
"""Stand-in for a container engine daemon (Docker is not installed on the nodes): listens on the hosts
given with -H (unix://path or tcp://addr:port) and answers "OK". Used by question 17."""
import os
import socket
import sys
import threading

hosts = []
args = sys.argv[1:]
i = 0
while i < len(args):
    if args[i] == '-H' and i + 1 < len(args):
        hosts.append(args[i + 1])
        i += 2
    elif args[i].startswith('-H') and len(args[i]) > 2:
        hosts.append(args[i][2:])
        i += 1
    else:
        i += 1


def serve(sock):
    sock.listen(8)
    while True:
        conn, _ = sock.accept()
        try:
            conn.sendall(b'OK\n')
        finally:
            conn.close()


threads = []
for h in hosts:
    if h.startswith('unix://'):
        path = h[len('unix://'):]
        if os.path.exists(path):
            os.unlink(path)
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(path)
    elif h.startswith('tcp://'):
        addr, port = h[len('tcp://'):].rsplit(':', 1)
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((addr, int(port)))
    else:
        continue
    t = threading.Thread(target=serve, args=(s,), daemon=True)
    t.start()
    threads.append(t)

for t in threads:
    t.join()
