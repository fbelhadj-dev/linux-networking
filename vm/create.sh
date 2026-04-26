#!/bin/bash
set -e

VM='alpine-virt-3_23_4-x86_64'

tmux kill-session -t "$VM"
ip link del tap0 2>/dev/null || true

ip tuntap add tap0 mode tap # Creating a tap device to connect to the VM
ip addr add 192.168.100.1/24 dev tap0

args=(
  -enable-kvm # Use hardware acceleration 
  -m 256 # Memory allocation in MB
  -drive file=/var/lib/libvirt/images/"$VM".qcow2,format=qcow2 # Virtual disk
  -cdrom /var/lib/libvirt/boot/"$VM".iso # ISO
  -boot d # Boot order (d = cdrom)
  -display none # No GUI
  -serial mon:stdio # Link terminal to guest serial
  -netdev tap,ifname=tap0,id=net0,script=no,downscript=no # Attach to the host tap device
  -device virtio-net-pci,netdev=net0,id=nic0 # Create virtual NIC for the VM to forward raw Ethernet frame to the tap device
)

tmux new-session -s "$VM" "qemu-system-x86_64 ${args[*]}" # Starting session with tmux to run the VM in background

# Set up connectivity inside the VM 
tmux send-keys -t "$VM" "ip addr add 192.168.100.2/24 dev eth0" ENTER
tmux send-keys -t "$VM" "ip link set eth0 up" ENTER
tmux send-keys -t "$VM" "ip route add default via 192.168.100.1" ENTER

ip link set tap0 up
ping 192.168.100.2 -c 1 # Ping the VM

# Give VM access to internet 
DNS_CONTENT=$(cat /etc/resolv.conf)

tmux send-keys -t "$VM" "echo \"$DNS_CONTENT\" > /etc/resolv.conf" ENTER
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
