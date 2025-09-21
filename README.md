# Raspberry Pi Cluster

[![CI](https://github.com/geerlingguy/pi-cluster/actions/workflows/ci.yml/badge.svg)](https://github.com/geerlingguy/pi-cluster/actions/workflows/ci.yml)

<p align="center"><a href="https://www.youtube.com/watch?v=kgVz4-SEhbE"><img src="images/turing-pi-2-hero.jpg?raw=true" width="500" height="auto" alt="Turing Pi 2 - Raspberry Pi Compute Module Cluster" /></a></p>

This repository contains examples and automation used in various Raspberry Pi clustering scenarios, as seen on [Jeff Geerling's YouTube channel](https://www.youtube.com/c/JeffGeerling).

<p align="center"><a href="https://www.youtube.com/watch?v=ecdm3oA-QdQ"><img src="images/deskpi-super6c-running.jpg?raw=true" width="500" height="auto" alt="DeskPi Super6c Mini ITX Raspberry Pi Compute Module Cluster" /></a></p>

The inspiration for this project was my first Pi cluster, the [Raspberry Pi Dramble](https://www.pidramble.com), which is still running in my basement to this day!

> **See also**: [Beowulf AI Cluster](https://github.com/geerlingguy/beowulf-ai-cluster) (AI clustering playbooks with a very similar architecture to this project)

## Usage

  1. Make sure you have [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed.
  2. Copy the `example.hosts.ini` inventory file to `hosts.ini`. Make sure it has the `control_plane` and `node`s configured correctly (for my examples I named my nodes `node[1-4].local`).
  3. Copy the `example.config.yml` file to `config.yml`, and modify the variables to your liking.

### Raspberry Pi Setup

I am running Raspberry Pi OS on various Pi clusters. You can run this on any Pi cluster, but I tend to use Compute Modules without eMMC ('Lite' versions) and I often run them using [32 GB SanDisk Extreme microSD cards](https://amzn.to/3G35QbY) to boot each node. For some setups (like when I run the [Compute Blade](https://computeblade.com) or [DeskPi Super6c](https://deskpi.com/collections/deskpi-super6c), I boot off NVMe SSDs instead.

In every case, I flashed Raspberry Pi OS (64-bit, lite) to the storage devices using Raspberry Pi Imager.

To make network discovery and integration easier, I edit the advanced configuration in Imager, and set the following options:

  - Set hostname: `node1.local` (set to `2` for node 2, `3` for node 3, etc.)
  - Enable SSH: 'Allow public-key', and paste in my public SSH key(s)
  - Configure wifi: (ONLY on node 1, if desired) enter SSID and password for local WiFi network

After setting all those options, making sure only node 1 has WiFi configured, and the hostname is unique to each node (and matches what is in `hosts.ini`), I inserted the microSD cards into the respective Pis, or installed the NVMe SSDs into the correct slots, and booted the cluster.

### SSH connection test

To test the SSH connection from my Ansible controller (my main workstation, where I'm running all the playbooks), I connected to each server individually, and accepted the hostkey:

```
ssh pi@node1.local
```

This ensures Ansible will also be able to connect via SSH in the following steps. You can test Ansible's connection with:

```
ansible all -m ping
```

It should respond with a 'SUCCESS' message for each node.

### Storage Configuration

This playbook will create a storage location on node 3 by default. You can use one of the storage configurations by switching the `storage_type` variable from `filesystem` to `zfs` in your `config.yml` file.

#### Filesystem Storage

If using filesystem (`storage_type: filesystem`), make sure to use the appropriate `storage_nfs_dir` variable in `config.yml`.

#### ZFS Storage

If using ZFS (`storage_type: zfs`, you should have two volumes available on node 3, `/dev/sda`, and `/dev/sdb`, able to be pooled into a mirror. Make sure your two SATA drives are wiped:

```
pi@node3:~ $ sudo wipefs --all --force /dev/sda?; sudo wipefs --all --force /dev/sda
pi@node3:~ $ sudo wipefs --all --force /dev/sdb?; sudo wipefs --all --force /dev/sdb
```

If you run `lsblk`, you should see `sda` and `sdb` have no partitions, and are ready to use:

```
pi@node3:~ $ lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0  1.8T  0 disk 
sdb           8:16   0  1.8T  0 disk 
```

You should also make sure the `storage_nfs_dir` variable is set appropriately for ZFS in your `config.yml`.

This ZFS layout was configured originally for the Turing Pi 2 board, which has two built-in SATA ports connected directly to node 3. In the future, the configuration may be genericized a bit better.

#### Ceph Storage Configuration

You could also run Ceph on a Pi cluster—see the storage configuration playbook inside the `ceph` directory.

This configuration is not yet integrated into the general K3s setup.

### Cluster configuration and K3s installation

First, make sure Ansible requirements are installed:

```
ansible-galaxy install -r requirements.yml --force
```

Configure static networking, if your cluster nodes don't already have static IP addresses—see later section in this README.

Then, run the playbook:

```
ansible-playbook main.yml
```

At the end of the playbook, there should be an instance of Drupal running on the cluster. If you log into node 1, you should be able to access it with `curl localhost`.

> If the playbook stalls while installing K3s, [you might need to configure static IP addresses](https://github.com/geerlingguy/pi-cluster/issues/11#issuecomment-1983874999) for the nodes, especially if using mDNS (like with `.local` names for the nodes). Follow the guide in "Static network configuration" then run the `main.yml` playbook again afterwards, and it should get things in order.

If you have SSH tunnelling configured (see later section), you could access `http://[your-vps-ip-or-hostname]:8080/` and you'd see the site.

You can also log into node 1, switch to the root user account (`sudo su`), then use `kubectl` to manage the cluster (e.g. view Drupal pods with `kubectl get pods -n drupal`).

The Kubernetes Ingress object for Drupal (how HTTP requests from outside the cluster make it to Drupal) can be found by running `kubectl get ingress -n drupal`. Take the IP address or hostname there and enter it in your browser on a computer on the same network, and voila! You should see Drupal's installer.

K3s' `kubeconfig` file is located at `/etc/rancher/k3s/k3s.yaml`. If you'd like to manage the cluster from other hosts (or using a tool like Lens), copy the contents of that file, replacing `localhost` with the IP address or hostname of the control plane node, and paste the contents into a file `~/.kube/config`.

Alternatively, if you'd like to use [k9s](https://k9scli.io) on the main Pi itself, symlink the rancher kubeconfig file into a location where k9s expects to see it:

```
# (perform all commands as root user)
# Download and install K9s
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_arm64.deb && apt install ./k9s_linux_arm64.deb && rm k9s_linux_arm64.deb

# Symlink K3s kubeconfig into root user's home directory
ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Launch k9s
k9s
```

### Upgrading the cluster

Run the upgrade playbook:

```
ansible-playbook upgrade.yml
```

### Monitoring the cluster

Prometheus and Grafana are used for monitoring. Grafana can be accessed via port forwarding (or you could choose to expose it another way).

To access Grafana:

  1. Make sure you set up a valid `~/.kube/config` file (see 'K3s installation' above).
  1. Run `kubectl port-forward service/cluster-monitoring-grafana :80`
  1. Grab the port that's output, and browse to `localhost:[port]`, and bingo! Grafana.

The default login is `admin` / `prom-operator`, but you can also get the secret with `kubectl get secret cluster-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -D`.

You can then browse to all the Kubernetes and Pi-related dashboards by browsing the Dashboards in the 'General' folder.

### Benchmarking the cluster

See the README file within the `benchmarks` folder.

### Shutting down the cluster

The safest way to shut down the cluster is to run the following command:

```
ansible all -m community.general.shutdown -b
```

> Note: If using the SSH tunnel, you might want to run the command _first_ on nodes 2-4, _then_ on node 1. So first run `ansible 'all:!control_plane' [...]`, then run it again just for `control_plane`.

Then after you confirm the nodes are shut down (with K3s running, it can take a few minutes), press the cluster's power button (or yank the Ethernet cables if using PoE) to power down all Pis physically. Then you can switch off or disconnect your power supply.

### Static network configuration (highly recommended)

Kubernetes generally likes static network routes, especially when using DNS to connect to other nodes in a cluster.

There is a playbook which configures static networking so your nodes maintain the same IP address after a reboot, even under different networking scenarios.

If using your cluster both on-premise and remote (e.g. using 4G LTE connected to the first Pi), you can set it up on its _own_ subnet (e.g. `10.1.1.x`). Otherwise, you can set it to the same subnet as your local network.

Configure the subnet via the `ipv4_subnet_prefix` variable in `config.yml`, then run the playbook:

```
ansible-playbook networking.yml
```

After running the playbook, until a reboot, the Pis will still be accessible over their former DHCP-assigned IP address. After rebooting, the nodes will be accessible on their new IP addresses.

You can reboot all the nodes with:

```
ansible all -m reboot -b
```

> If you are running Ubuntu, and you get an error like `"Failed to find required executable "nmcli"`, run the `ubuntu-setup.yml` playbook: `ansible-playbook tasks/networking/ubuntu-prep.yml`

#### If using a different subnet

If you chose a different subnet than your LAN, make sure your workstation is connected to an interface on the same subnet as the cluster (e.g. `10.1.1.x`).

After the networking changes are made, since this playbook uses DNS names (e.g. `node1.local`) instead of IP addresses, your computer will still be able to connect to the nodes directly—assuming your network has IPv6 support. Pinging the nodes on their new IP addresses will _not_ work, however. For better network compatibility, it's recommended you set up a separate network interface on the Ansible controller that's on the same subnet as the Pis in the cluster:

On my Mac, I connected a second network interface and manually configured its IP address as `10.1.1.10`, with subnet mask `255.255.255.0`, and that way I could still access all the nodes via IP address or their hostnames (e.g. `node2.local`).

Because the cluster subnet needs its own router, node 1 is configured as a router, using `wlan0` as the primary interface for Internet traffic by default. The other nodes get their Internet access through node 1.

#### Switch between 4G LTE and WiFi (optional)

The network configuration defaults to an `active_internet_interface` of `wlan0`, meaning node 1 will route all Internet traffic for the cluster through it's WiFi interface.

Assuming you have a [working 4G card in slot 1](https://www.jeffgeerling.com/blog/2022/using-4g-lte-wireless-modems-on-raspberry-pi), you can switch node 1 to route through an alternate interface (e.g. `usb0`):

  1. Set `active_internet_interface: "usb0"` in your `config.yml`
  2. Run the networking playbook again: `ansible-playbook networking.yml`

You can switch back and forth between interfaces using the steps above.

#### Reverse SSH and HTTP tunnel configuration (optional)

For my own experimentation, I ran my Pi cluster 'off-grid', using a 4G LTE modem, as mentioned above.

Because my mobile network provider uses CG-NAT, there is no way to remotely access the cluster, or serve web traffic to the public internet from it, at least not out of the box.

I am using a reverse SSH tunnel to enable direct remote SSH and HTTP access. To set that up, I configured a VPS I run to use TCP Forwarding (see [this blog post for details](https://www.jeffgeerling.com/blog/2022/ssh-and-http-raspberry-pi-behind-cg-nat)), and I configured an SSH key so node 1 could connect to my VPS (e.g. `ssh my-vps-username@my-vps-hostname-or-ip`).

Then I set the `reverse_tunnel_enable` variable to `true` in my `config.yml`, and configured the VPS username and hostname options.

Doing that and running the `main.yml` playbook configures `autossh` on node 1, and will try to get a connection through to the VPS on ports 2222 (to node 1's port 22) and 8080 (to node 1's port 80).

After that's done, you should be able to log into the cluster _through_ your VPS with a command like:

```
$ ssh -p 2222 pi@[my-vps-hostname]
```

> Note: If autossh isn't working, it could be that it didn't exit cleanly, and a tunnel is still reserving the port on the remote VPS. That's often the case if you run `sudo systemctl status autossh` and see messages like `Warning: remote port forwarding failed for listen port 2222`.
>
> In that case, log into the remote VPS and run `pgrep ssh | xargs kill` to kill off all active SSH sessions, then `autossh` should pick back up again.

> **Warning**: Use this feature at your own risk. Security is your own responsibility, and for better protection, you should probably avoid directly exposing your cluster (e.g. by disabling the `GatewayPorts` option) so you can only access the cluster while already logged into your VPS).

## Caveats

These playbooks are used in both production and test clusters, but security is _always_ your responsibility. If you want to use any of this configuration in production, take ownership of it and understand how it works so you don't wake up to a hacked Pi cluster one day!

## Author

The repository was created in 2023 by [Jeff Geerling](https://www.jeffgeerling.com), author of [Ansible for DevOps](https://www.ansiblefordevops.com), [Ansible for Kubernetes](https://www.ansibleforkubernetes.com), and [Kubernetes 101](https://www.kubernetes101book.com).
