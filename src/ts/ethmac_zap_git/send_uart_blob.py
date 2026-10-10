#!/usr/bin/env python3
import argparse
import struct
import time
import serial

MAGIC = 0x5A504C44  # "ZPLD"

def wait_for_ok(ser, timeout_s=20):
    import time

    deadline = time.time() + timeout_s
    window = b""

    while time.time() < deadline:
        b = ser.read(1)
        if not b:
            continue

        print(b.decode(errors="ignore"), end="", flush=True)

        window = (window + b)[-2:]
        if window == b"OK":
            print("\nACK OK")
            return

    return
    raise RuntimeError("Timed out waiting for OK")

def send_blob(ser, filename, addr, chunk_delay=0.0):
    with open(filename, "rb") as f:
        data = f.read()

    header = struct.pack("<III", MAGIC, addr, len(data))

    print(f"Sending {filename}")
    print(f"  addr = 0x{addr:08X}")
    print(f"  size = 0x{len(data):08X} ({len(data)} bytes)")

    ser.write(header)
    ser.flush()

    chunk = 1024
    sent = 0

    while sent < len(data):
        part = data[sent:sent + chunk]
        ser.write(part)
        ser.flush()
        sent += len(part)

        if chunk_delay:
            time.sleep(chunk_delay)

        if sent % (64 * 1024) < chunk:
            print(f"  sent {sent}/{len(data)}")

    print("Waiting for ACK...")
    #wait_for_ok(ser)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True, help="Serial port, e.g. /dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=19200)
    ap.add_argument("--zimage", required=True)
    ap.add_argument("--dtb", required=True)
    ap.add_argument("--zaddr", type=lambda x: int(x, 0), default=0x10800000)
    ap.add_argument("--dtbaddr", type=lambda x: int(x, 0), default=0x11000000)
    ap.add_argument("--delay", type=float, default=0.0, help="Delay between chunks")
    args = ap.parse_args()

    with serial.Serial(args.port, args.baud, timeout=10, xonxoff=False, rtscts=False, dsrdtr=False) as ser:
        time.sleep(1.0)
        ser.reset_input_buffer()

        send_blob(ser, args.zimage, args.zaddr, args.delay)

        print("Waiting before DTB transfer...")
        time.sleep(2.0)

        ser.reset_input_buffer()

        send_blob(ser, args.dtb, args.dtbaddr, args.delay)

    print("All done.")

if __name__ == "__main__":
    main()
