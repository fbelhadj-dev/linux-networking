set -e

sudo ip link del veth-host-c 2>/dev/null || true 
sudo ip link del veth-host-s 2>/dev/null || true
sudo ip netns del c 2>/dev/null || true
sudo ip netns del s 2>/dev/null || true

sudo umount /root/c /root/s 2>/dev/null || true
sudo ssh-keygen -f /root/.ssh/known_hosts -R 10.0.20.2 2>/dev/null || true

sudo ip netns add c # client
sudo ip netns add s # server

sudo ip -n c link set lo up
sudo ip -n s link set lo up

sudo ip link add veth-c type veth peer name veth-host-c
sudo ip link add veth-s type veth peer name veth-host-s

sudo ip addr add 10.0.10.1/24 dev veth-host-c
sudo ip addr add 10.0.20.1/24 dev veth-host-s

sudo ip link set veth-host-c up
sudo ip link set veth-host-s up

sudo sysctl -w net.ipv4.ip_forward=1

# Marks namespaces interfaces as trusted to avoid routing issues (needed to connect c and s namespaces)
sudo firewall-cmd --permanent --zone=trusted --add-interface=veth-host-c
sudo firewall-cmd --permanent --zone=trusted --add-interface=veth-host-s
sudo firewall-cmd --reload

sudo ip link set veth-c netns c
sudo ip link set veth-s netns s

sudo ip -n c addr add 10.0.10.2/24 dev veth-c
sudo ip -n s addr add 10.0.20.2/24 dev veth-s

sudo ip -n c link set veth-c up
sudo ip -n s link set veth-s up

sudo ip -n c route add default via 10.0.10.1
sudo ip -n s route add default via 10.0.20.1

sudo ip netns exec s mkdir -p /root/s
sudo ip netns exec s mount -t tmpfs tmpfs /root/s 

sudo ip netns exec s mkdir -p /root/s/ssh
sudo ip netns exec s chmod 700 /root/s/ssh

sudo ip netns exec s ssh-keygen -t ed25519 -f /root/s/ssh/host_ed25519 -N ''
sudo ip netns exec s tee /root/s/sshd_config <<EOF
Port 22
ListenAddress 0.0.0.0
HostKey /root/s/ssh/host_ed25519
PidFile /root/sshd_s.pid
PermitRootLogin prohibit-password
PasswordAuthentication no
AuthorizedKeysFile /root/s/authorized_keys
EOF

sudo ip netns exec s touch /root/s/authorized_keys
sudo ip netns exec s chmod 600 /root/s/authorized_keys

sudo ip netns exec s /usr/bin/sshd -f /root/s/sshd_config # Running ssh server inside s namespace

sudo ip netns exec c mkdir -p /root/c
sudo ip netns exec c mount -t tmpfs tmpfs /root/c 

sudo ip netns exec c mkdir -p /root/c/ssh
sudo ip netns exec c chmod 700 /root/c/ssh

sudo ip netns exec c ssh-keygen -t ed25519 -f /root/c/ssh/host_ed25519 -N ''
sudo ip netns exec c cat /root/c/ssh/host_ed25519.pub | sudo ip netns exec s tee /root/s/authorized_keys

sudo ip netns exec c ssh -i /root/c/ssh/host_ed25519 root@10.0.20.2 # Connecting to s namespace from c namespace using ssh