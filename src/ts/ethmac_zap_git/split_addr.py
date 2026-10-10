#!/usr/bin/env python3

import sys

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <address>")
    print(f"Example: {sys.argv[0]} 0x100000904")
    sys.exit(1)

pc = int(sys.argv[1], 0)

print(f"pc       = 0x{pc:X}")
print(f"[31:30] = 0x{(pc >> 30) & 0x7:X}")
print(f"[29:20] = 0x{(pc >> 20) & 0x3FF:X}")
print(f"[19:10] = 0x{(pc >> 10) & 0x3FF:X}")
print(f"[9:3]   = 0x{(pc >> 3)  & 0x7F:X}")
print(f"[2]     = {(pc >> 2) & 1}")
print(f"[1]     = {(pc >> 1) & 1}")
print(f"[0]     = {pc & 1}")
