#!/usr/bin/python

import os, socket, struct, sys
from fcntl import ioctl
from select import select

from cryptography.fernet import Fernet

IF_NAME, REMOTE_IP, FERNET_KEY = sys.argv[1:]

cipher = Fernet(FERNET_KEY)
print("Successfully created cipher for encrypted tunnel")


# Constants
PORT = 4444
BUF_SIZE = 2048

# Constants defined in the Linux kernel headers
TUNSETIFF = 0x400454ca
IFF_TUN   = 0x0001
IFF_NO_PI = 0x1000  # Do not provide packet information header


def create_tun() -> int:
    tun = os.open("/dev/net/tun", os.O_RDWR)
    ifr = struct.pack("16sH", IF_NAME.encode(), IFF_TUN | IFF_NO_PI)

    ioctl(tun, TUNSETIFF, ifr) # Attach to tun interface IF_NAME

    print(f"Successfully attached to {IF_NAME}")

    return tun


def create_udp_socket() -> socket.socket:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP socket
    sock.bind(("0.0.0.0", PORT))

    print(f"Successfully binded to port {PORT}")

    return sock

try:
    tun = create_tun() # Get tunnel interface
    sock = create_udp_socket() # Create udp socket to send encrypted/decrypted data

    while True:
        read_ready, _, _ = select([tun, sock], [], []) # Get streams ready for read

        for fd in read_ready:
            if fd == tun: 
                packet = os.read(tun, BUF_SIZE) 
                ecnrypted_packet = cipher.encrypt(packet) # Encrypt packet
                sock.sendto(ecnrypted_packet, (REMOTE_IP, PORT)) # Send it over UDP
            
            elif fd == sock:
                packet, _ = sock.recvfrom(BUF_SIZE) # Receive packet from UDP socket
                decrypted_packet = cipher.decrypt(packet) # Decrypt packet
                os.write(tun, decrypted_packet) # Write decrypted packet to the char device for the kernel to forward it 

except KeyboardInterrupt:
    print(f"\nClosing interface {IF_NAME}.")