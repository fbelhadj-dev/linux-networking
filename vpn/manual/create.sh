#!/bin/bash
set -e

ip netns del vpn-server 2>/dev/null || true
ip netns del vpn-client 2>/dev/null || true
ip link del veth0-vpns 2>/dev/null || true
ip link del veth0-vpnc 2>/dev/null || true

ip link add veth0-vpns type veth peer name veth0-vpnc

ip netns add vpn-server
ip link set veth0-vpns netns vpn-server
ip -n vpn-server link set lo up
ip -n vpn-server link set veth0-vpns name eth0
ip -n vpn-server link set eth0 up
ip -n vpn-server addr add 192.168.200.1/24 dev eth0
ip -n vpn-server tuntap add dev vpn0 mode tun
ip -n vpn-server link set vpn0 up
ip -n vpn-server addr add 10.0.0.1/24 dev vpn0
ip -n vpn-server route add default via 10.0.0.1



ip netns add vpn-client
ip link set veth0-vpnc netns vpn-client
ip -n vpn-client link set lo up
ip -n vpn-client link set veth0-vpnc name eth0
ip -n vpn-client link set eth0 up
ip -n vpn-client addr add 192.168.200.2/24 dev eth0
ip -n vpn-client tuntap add dev vpn0 mode tun
ip -n vpn-client link set vpn0 up
ip -n vpn-client addr add 10.0.0.2/24 dev vpn0
ip -n vpn-client route add default via 10.0.0.2