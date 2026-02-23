sudo ip netns add wg-client

sudo ip link add veth0 type veth peer name veth0-wg-client

sudo ip addr add 192.168.200.1/24 dev veth0
sudo ip link set veth0 up

sudo ip link set veth0-wg-client netns wg-client
sudo ip -n wg-client link set veth0-wg-client name veth0
sudo ip -n wg-client addr add 192.168.200.2/24 dev veth0
sudo ip -n wg-client link set veth0 up

sudo ip -n wg-client route add default via 192.168.200.1

sudo ip link add wg0 type wireguard
sudo ip addr add 10.0.0.1/24 dev wg0
wg genkey | tee /tmp/private.host | wg pubkey | tee /tmp/public.host
sudo ip link set wg0 up

sudo ip -n wg-client link add wg0 type wireguard
sudo ip -n wg-client addr add 10.0.0.2/24 dev wg0
wg genkey | tee /tmp/private.ns | wg pubkey | tee /tmp/public.ns
sudo ip -n wg-client link set wg0 up

sudo wg set wg0 private-key /tmp/private.host listen-port 51820 peer $(cat /tmp/public.ns) allowed-ips 10.0.0.2/32
sudo ip netns exec wg-client wg set wg0 private-key /tmp/private.ns peer $(cat /tmp/public.host) endpoint 192.168.200.1:51820 allowed-ips 10.0.0.1/32