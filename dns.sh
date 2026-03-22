#!/bin/bash
set -e

namespaces=( ns-client ns-resolver ns-root ns-tld ns-auth )

# Killing named processes
sudo ip netns exec ns-resolver pkill named 2>/dev/null || true
sudo ip netns exec ns-root pkill named 2>/dev/null || true
sudo ip netns exec ns-tld pkill named 2>/dev/null || true
sudo ip netns exec ns-auth pkill named 2>/dev/null || true

# Removing directories
rm -rf /tmp/bind || true

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

sudo ip -n ns-resolver route add 10.0.2.0/24 via 10.0.1.2 dev veth1
sudo ip -n ns-resolver route add 10.0.3.0/24 via 10.0.1.2 dev veth1

sudo ip -n ns-root route add 10.0.0.0/24 via 10.0.1.1
sudo ip -n ns-root route add 10.0.3.0/24 via 10.0.2.1

sudo ip -n ns-tld route add 10.0.0.0/24 via 10.0.2.2
sudo ip -n ns-tld route add 10.0.1.0/24 via 10.0.2.2

sudo ip -n ns-auth route add default via 10.0.3.1

# BIND directories
mkdir -p /tmp/bind/ns-auth /tmp/bind/ns-tld /tmp/bind/ns-root /tmp/bind/ns-resolver
chmod -R 777 /tmp/bind

# Resolver server
tee /tmp/bind/ns-resolver/named.conf <<EOF
options {
    directory "/tmp/bind/ns-resolver";
    recursion yes;
    listen-on { 10.0.0.1; };
    allow-query { any; };
};
zone "." {
    type hint;
    file "root.hints";
};
EOF

tee /tmp/bind/ns-resolver/root.hints <<EOF
.       IN NS ns-root.
ns-root. IN A 10.0.1.2
EOF

# Root server
tee /tmp/bind/ns-root/named.conf <<EOF
options {
    directory "/tmp/bind/ns-root";
    recursion no;
    listen-on { 10.0.1.2; };
};
zone "." {
    type master;
    file "db.root";
};
EOF

tee /tmp/bind/ns-root/db.root <<EOF
\$TTL 3600
@ IN SOA ns-root. admin.root. (1 3600 3600 3600 3600)
@   IN NS ns-root.
ns-root. IN A 10.0.1.2

; delegation to tld
lab.   IN NS ns-tld.lab.
ns-tld.lab. IN A 10.0.2.1
EOF

# TLD server
tee /tmp/bind/ns-tld/named.conf <<EOF
options {
    directory "/tmp/bind/ns-tld";
    recursion no;
    listen-on { 10.0.2.1; };
};
zone "lab" {
    type master;
    file "db.lab";
};
EOF

tee /tmp/bind/ns-tld/db.lab <<EOF
\$TTL 3600
@ IN SOA ns-tld.lab. admin.lab. (
    1 3600 3600 3600 3600 )

; delegation to auth
@           IN NS ns-auth.lab.
ns-auth.lab. IN A 10.0.3.2
EOF

# Auth server
tee /tmp/bind/ns-auth/named.conf <<EOF
options {
    directory "/tmp/bind/ns-auth";
    recursion no;
    listen-on { 10.0.3.2 };
};
zone "lab" {
    type master;
    file "db.lab";
};
EOF

tee /tmp/bind/ns-auth/db.lab <<EOF
\$TTL 3600
@ IN SOA ns-auth.lab. admin.lab. (
    1 3600 3600 3600 3600 )

; Fake IP resolution
test IN A 10.0.3.3
EOF

# Start BIND in namespaces
sudo ip netns exec ns-resolver named -c /tmp/bind/ns-resolver/named.conf &
sleep 1
sudo ip netns exec ns-root named -c /tmp/bind/ns-root/named.conf &
sleep 1
sudo ip netns exec ns-tld named -c /tmp/bind/ns-tld/named.conf &
sleep 1
sudo ip netns exec ns-auth named -c /tmp/bind/ns-auth/named.conf &
sleep 1

# Testing full resolution 
sudo ip netns exec ns-client dig test.lab 

# config is kept minimal on purpose ! The goal is not only to make it work but to mimic real DNS servers !