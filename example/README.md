# DreamStream Example

This example uses the `NVC` VHDL simulator together with [openprj](https://codeberg.org/gsi-ee/openprj) and the included SimMAC module.

SimMAC emulates an Ethernet MAC in VHDL and exposes it to the host system as a Linux `veth` interface. From the host's perspective, it behaves like a real network device, making it possible to interact with the simulated hardware using standard networking tools.

## Running the Simulation

### Development Environment

You can install `openprj` and `NVC` manually, but the easiest option is to use the provided Nix flake.

After installing Nix, enter the development environment with:

```bash
sudo nix develop
```

### Create a Working Directory

```bash
mkdir workdir
cd workdir
```

### Start the Simulation

```bash
openprj --sim ../example.prj
```

The simulation must be run as `root`, since creating and managing `veth` interfaces requires elevated privileges.

You can now see from the simulation output that it sends DHCP requests. You can also verify that on the host side using `wireshark` or `tcpdump`. To make DHCP succeed, continue with the following sections. After that, you are also able to ping the simulation.

---

## Host Network Configuration

To provide the simulated device with network connectivity, the host system must:

- Configure the host-side `veth` interface to assign an IP address to that interface.
- Run a DHCP server for the simulated device.

The examples below use `NetworkManager` and `dnsmasq`.

### Allow NetworkManager to Manage `veth` Interfaces

Create the file:

```text
/etc/udev/rules.d/90-nm-managed-veth.rules
```

with the following contents:

```text
ENV{ID_NET_DRIVER}=="veth", ENV{NM_UNMANAGED}="0"
```

Reload the udev rules:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Configure the Host Interface

Start the simulation once so that the `ds_host` interface is created.

Then add a `NetworkManager` connection:

```bash
nmcli connection add \
    type ethernet \
    ipv6.method disabled \
    ipv4.method manual \
    ipv4.addresses "10.111.0.1/24" \
    con-name ds-host \
    ifname ds_host
```

### Configure DHCP

Install and configure a DHCP server such as `dnsmasq`.

Example `dnsmasq.conf`:

```text
local-service

interface=ds_host
dhcp-range=10.111.0.100,10.111.0.200,24h
dhcp-authoritative
```

Restart `dnsmasq` after applying the configuration.

Once configured, the simulated device will automatically receive an IP address from the DHCP server whenever the simulation is started. Now you can ping the simulation.

```bash
ping 10.111.0.123
```

