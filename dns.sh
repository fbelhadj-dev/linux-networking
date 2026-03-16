#!/bin/bash
set -e

namespaces=( ns-client ns-resolver ns-root ns-tld ns-auth )

# Clean up old namespaces and veths
for ns in "${namespaces[@]}"; do 
    sudo ip netns del $ns 2>/dev/null || true
done

sudo ip link del veth-ns-client 2>/dev/null || true
sudo ip link del veth-ns-res1 2>/dev/null || true
sudo ip link del veth-ns-root1 2>/dev/null || true
sudo ip link del veth-ns-tld1 2>/dev/null || true

# Create namespaces
for ns in "${namespaces[@]}"; do 
    sudo ip netns add $ns
    sudo ip -n $ns link set lo up
done

sudo ip netns exec ns-resolver sysctl net.ipv4.ip_forward=1
sudo ip netns exec ns-root sysctl net.ipv4.ip_forward=1
sudo ip netns exec ns-tld sysctl net.ipv4.ip_forward=1

# Client <-> Resolver
sudo ip link add veth-ns-client type veth peer name veth-ns-res0
sudo ip link set veth-ns-res0 netns ns-resolver
sudo ip -n ns-resolver link set veth-ns-res0 name veth0
sudo ip -n ns-resolver addr add 10.0.0.1/24 dev veth0
sudo ip -n ns-resolver link set veth0 up

sudo ip link set veth-ns-client netns ns-client
sudo ip -n ns-client link set veth-ns-client name veth0
sudo ip -n ns-client addr add 10.0.0.2/24 dev veth0
sudo ip -n ns-client link set veth0 up

sudo mkdir -p /etc/netns/ns-client
echo "nameserver 10.0.0.1" | sudo tee /etc/netns/ns-client/resolv.conf

sudo mkdir -p /etc/netns/ns-resolver
echo "nameserver 10.0.0.1" | sudo tee /etc/netns/ns-resolver/resolv.conf

# Resolver <-> Root
sudo ip link add veth-ns-res1 type veth peer name veth-ns-root0
sudo ip link set veth-ns-root0 netns ns-root
sudo ip -n ns-root link set veth-ns-root0 name veth0
sudo ip -n ns-root addr add 10.0.1.2/24 dev veth0
sudo ip -n ns-root link set veth0 up

sudo ip link set veth-ns-res1 netns ns-resolver
sudo ip -n ns-resolver link set veth-ns-res1 name veth1
sudo ip -n ns-resolver addr add 10.0.1.1/24 dev veth1
sudo ip -n ns-resolver link set veth1 up

# Root <-> TLD
sudo ip link add veth-ns-root1 type veth peer name veth-ns-tld0
sudo ip link set veth-ns-tld0 netns ns-tld
sudo ip -n ns-tld link set veth-ns-tld0 name veth0
sudo ip -n ns-tld addr add 10.0.2.1/24 dev veth0
sudo ip -n ns-tld link set veth0 up

sudo ip link set veth-ns-root1 netns ns-root
sudo ip -n ns-root link set veth-ns-root1 name veth1
sudo ip -n ns-root addr add 10.0.2.2/24 dev veth1
sudo ip -n ns-root link set veth1 up

# TLD <-> Auth
sudo ip link add veth-ns-tld1 type veth peer name veth-ns-auth0
sudo ip link set veth-ns-auth0 netns ns-auth
sudo ip -n ns-auth link set veth-ns-auth0 name veth0
sudo ip -n ns-auth addr add 10.0.3.2/24 dev veth0
sudo ip -n ns-auth link set veth0 up

sudo ip link set veth-ns-tld1 netns ns-tld
sudo ip -n ns-tld link set veth-ns-tld1 name veth1
sudo ip -n ns-tld addr add 10.0.3.1/24 dev veth1
sudo ip -n ns-tld link set veth1 up

# Routes
sudo ip -n ns-client route add default via 10.0.0.1

sudo ip -n ns-resolver route add 10.0.2.0/24 via 10.0.1.2 dev veth1 onlink
sudo ip -n ns-resolver route add 10.0.3.0/24 via 10.0.1.2 dev veth1 onlink

sudo ip -n ns-root route add 10.0.0.0/24 via 10.0.1.1
sudo ip -n ns-root route add 10.0.3.0/24 via 10.0.2.2

sudo ip -n ns-tld route add 10.0.0.0/24 via 10.0.2.1
sudo ip -n ns-tld route add 10.0.1.0/24 via 10.0.2.1

sudo ip -n ns-auth route add default via 10.0.3.1