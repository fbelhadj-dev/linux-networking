set -e

sudo ip netns del ns1 2>/dev/null || true
sudo ip netns del ns2 2>/dev/null || true
sudo ip netns del ns-router 2>/dev/null || true

#

sudo ip netns add ns-router
sudo ip -n ns-router link set lo up

sudo ip netns add ns1
sudo ip -n ns1 link set lo up

sudo ip netns add ns2
sudo ip -n ns2 link set lo up

#

sudo ip link add veth1 type veth peer name veth-ns1
sudo ip link set veth1 netns ns1
sudo ip link set veth-ns1 netns ns-router

sudo ip link add veth2 type veth peer name veth-ns2
sudo ip link set veth2 netns ns2
sudo ip link set veth-ns2 netns ns-router

#

sudo ip -n ns-router link set veth-ns1 up
sudo ip -n ns-router a add 10.0.1.1/24 dev veth-ns1

sudo ip -n ns-router link set veth-ns2 up
sudo ip -n ns-router a add 10.0.2.1/24 dev veth-ns2

sudo ip netns exec ns-router sysctl -w net.ipv4.ip_forward=1

sudo ip -n ns1 link set veth1 up
sudo ip -n ns1 a add 10.0.1.2/24 dev veth1
sudo ip -n ns1 route add default via 10.0.1.1

sudo ip -n ns2 link set veth2 up
sudo ip -n ns2 a add 10.0.2.2/24 dev veth2
sudo ip -n ns2 route add default via 10.0.2.1