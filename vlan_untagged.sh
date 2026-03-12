set -e

sudo ip netns del ns1 2>/dev/null || true
sudo ip netns del ns2 2>/dev/null || true
sudo ip netns del ns3 2>/dev/null || true
sudo ip netns del ns4 2>/dev/null || true

sudo ip link del veth-br1 2>/dev/null || true
sudo ip link del veth-br2 2>/dev/null || true
sudo ip link del veth-br3 2>/dev/null || true
sudo ip link del veth-br4 2>/dev/null || true

sudo ip link del br-ns 2>/dev/null || true

# main L2 managed switch

sudo ip link add br-ns type bridge vlan_filtering 1
sudo ip link set br-ns up

# ns1

sudo ip link add veth-br1 type veth peer name veth-ns1
sudo ip link set veth-br1 master br-ns

sudo bridge vlan d dev veth-br1 vid 1
sudo bridge vlan a dev veth-br1 vid 10 pvid untagged

sudo ip link set veth-br1 up

sudo ip netns a ns1
sudo ip link set veth-ns1 netns ns1
sudo ip -n ns1 a add 10.0.10.1/24 dev veth-ns1
sudo ip -n ns1 link set veth-ns1 up

# ns2

sudo ip link add veth-br2 type veth peer name veth-ns2
sudo ip link set veth-br2 master br-ns

sudo bridge vlan d dev veth-br2 vid 1
sudo bridge vlan a dev veth-br2 vid 10 pvid untagged

sudo ip link set veth-br2 up

sudo ip netns a ns2
sudo ip link set veth-ns2 netns ns2
sudo ip -n ns2 a add 10.0.10.2/24 dev veth-ns2
sudo ip -n ns2 link set veth-ns2 up

# ns3

sudo ip link add veth-br3 type veth peer name veth-ns3
sudo ip link set veth-br3 master br-ns

sudo bridge vlan d dev veth-br3 vid 1
sudo bridge vlan a dev veth-br3 vid 20 pvid untagged

sudo ip link set veth-br3 up

sudo ip netns a ns3
sudo ip link set veth-ns3 netns ns3
sudo ip -n ns3 a add 10.0.20.1/24 dev veth-ns3
sudo ip -n ns3 link set veth-ns3 up

# ns4

sudo ip link add veth-br4 type veth peer name veth-ns4
sudo ip link set veth-br4 master br-ns

sudo bridge vlan d dev veth-br4 vid 1
sudo bridge vlan a dev veth-br4 vid 20 pvid untagged

sudo ip link set veth-br4 up

sudo ip netns a ns4
sudo ip link set veth-ns4 netns ns4
sudo ip -n ns4 a add 10.0.20.2/24 dev veth-ns4
sudo ip -n ns4 link set veth-ns4 up

bridge vlan show