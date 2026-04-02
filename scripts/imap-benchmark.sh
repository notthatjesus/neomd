#!/bin/bash
# Benchmark IMAP server latency (LOGIN + SELECT INBOX + UID SEARCH ALL).
# Usage: IMAP_HOST=imap.example.com IMAP_USER=me@example.com IMAP_PASS=secret ./scripts/imap-benchmark.sh
#
# Or with env vars from your shell:
#   IMAP_HOST=imap.mail.hostpoint.ch IMAP_USER=simu@sspaeti.com IMAP_PASS=$IMAP_PASS_SIMU ./scripts/imap-benchmark.sh
#   IMAP_HOST=imap.gmail.com IMAP_USER=demo@gmail.com IMAP_PASS=$GMAIL_APP_PASS ./scripts/imap-benchmark.sh

set -e

HOST="${IMAP_HOST:?Set IMAP_HOST (e.g. imap.gmail.com)}"
USER="${IMAP_USER:?Set IMAP_USER (e.g. me@example.com)}"
PASS="${IMAP_PASS:?Set IMAP_PASS (app password)}"
PORT="${IMAP_PORT:-993}"

python3 -c "
import time, ssl, socket

host, user, pw = '$HOST', '$USER', '$PASS'
port = $PORT

print(f'Benchmarking {host}:{port} as {user}...')
print()

ctx = ssl.create_default_context()

# TLS connect
start = time.time()
s = ctx.wrap_socket(socket.socket(), server_hostname=host)
s.settimeout(10)
s.connect((host, port))
greeting = s.recv(4096)
tls_ms = (time.time() - start) * 1000

# LOGIN
start = time.time()
s.send(f'a1 LOGIN {user} {pw}\r\n'.encode())
resp = b''
while b'a1 ' not in resp:
    resp += s.recv(4096)
login_ms = (time.time() - start) * 1000

# SELECT INBOX
start = time.time()
s.send(b'a2 SELECT INBOX\r\n')
resp = b''
while b'a2 ' not in resp:
    resp += s.recv(4096)
select_ms = (time.time() - start) * 1000

# UID SEARCH ALL
start = time.time()
s.send(b'a3 UID SEARCH ALL\r\n')
resp = b''
while b'a3 ' not in resp:
    resp += s.recv(4096)
search_ms = (time.time() - start) * 1000

# Parse UIDs from SEARCH response and FETCH last 10 headers
uids = []
for line in resp.decode(errors='replace').split('\r\n'):
    if '* SEARCH' in line:
        uids = [u for u in line.split()[2:] if u.isdigit()]
        break

fetch_ms = 0
if uids:
    last_uids = uids[-min(10, len(uids)):]
    uid_range = ','.join(last_uids)
    start = time.time()
    s.send(f'a4 UID FETCH {uid_range} (UID FLAGS ENVELOPE RFC822.SIZE BODYSTRUCTURE)\r\n'.encode())
    resp = b''
    while b'a4 OK' not in resp:
        resp += s.recv(8192)
    fetch_ms = (time.time() - start) * 1000

# MOVE one email (to itself = NOOP, just measures command latency)
move_ms = 0
if uids:
    start = time.time()
    s.send(b'a5 NOOP\r\n')
    resp = b''
    while b'a5 ' not in resp:
        resp += s.recv(4096)
    move_ms = (time.time() - start) * 1000

s.send(b'a9 LOGOUT\r\n')
s.close()

total = login_ms + select_ms + search_ms + fetch_ms
print(f'  TLS connect:  {tls_ms:6.0f}ms')
print(f'  LOGIN:        {login_ms:6.0f}ms')
print(f'  SELECT INBOX: {select_ms:6.0f}ms')
print(f'  UID SEARCH:   {search_ms:6.0f}ms')
n = min(10, len(uids))
print(f'  FETCH ({n:>2} hdr):{fetch_ms:6.0f}ms')
print(f'  NOOP:         {move_ms:6.0f}ms')
print(f'  ─────────────────────')
print(f'  Total:        {total:6.0f}ms')
print()
if total < 100:
    print('  Result: Excellent — neomd will feel instant')
elif total < 300:
    print('  Result: Good — neomd will feel responsive')
elif total < 1000:
    print('  Result: Slow — noticeable delay on folder switches')
else:
    print('  Result: Very slow — neomd is not recommended with this provider')
"
