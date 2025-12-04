# Network Configuration Guide

## Overview

The SNO automation supports multiple network configuration options for the virtual machine:

1. **Default Pod Network** - Simple masquerade networking (default)
2. **NetworkAttachmentDefinition (NAD)** - Advanced networking with Multus CNI

## Default Pod Network

By default, the SNO VM uses pod networking with masquerade mode.

**Configuration:**
```yaml
# No additional configuration needed - this is the default
# Leave sno_network_attachment_definition empty
sno_network_attachment_definition: ""
```

**Characteristics:**
- Simple setup, no additional resources needed
- VM gets IP from pod network
- NAT/masquerade for external connectivity
- Good for basic deployments and testing

## NetworkAttachmentDefinition (NAD)

For production environments or specific network requirements, use a NetworkAttachmentDefinition.

### Prerequisites

1. **Multus CNI** must be installed (included with OpenShift Virtualization)
2. **Network infrastructure** (bridge, VLAN, etc.) must exist on worker nodes
3. **Appropriate CNI plugins** must be available

### Configuration Steps

#### 1. Create NetworkAttachmentDefinition

Choose an example based on your needs:

**Bridge Network (Simple):**
```bash
oc apply -f examples/network-attachment-definitions/bridge-network.yaml
```

**VLAN Network:**
```bash
oc apply -f examples/network-attachment-definitions/vlan-network.yaml
```

**OVS Network:**
```bash
oc apply -f examples/network-attachment-definitions/ovs-network.yaml
```

Or create your own custom NAD.

#### 2. Configure SNO to Use NAD

In your `host_vars` file:
```yaml
# Reference NAD with namespace/name format
sno_network_attachment_definition: "sno-clusters/vlan100-network"

# Optional: Set specific MAC address
sno_vm_mac_address: "52:54:00:aa:bb:cc"
```

#### 3. Deploy

```bash
./ansible-runner.sh deploy --limit sno-cluster-01
```

### NAD Format

The `sno_network_attachment_definition` variable accepts:

- **Full format:** `namespace/nad-name` (e.g., `sno-clusters/bridge-network`)
- **Short format:** `nad-name` (uses VM's namespace)

### Example NAD Configurations

#### Bridge Network with DHCP

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: bridge-network
  namespace: sno-clusters
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "bridge-network",
      "type": "bridge",
      "bridge": "br1",
      "ipam": {
        "type": "dhcp"
      }
    }
```

#### VLAN Network

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan100-network
  namespace: sno-clusters
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "vlan100-network",
      "type": "macvlan",
      "master": "eth1",
      "mode": "bridge",
      "vlan": 100,
      "ipam": {
        "type": "dhcp"
      }
    }
```

#### Static IP Configuration

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: static-ip-network
  namespace: sno-clusters
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "static-ip-network",
      "type": "bridge",
      "bridge": "br-static",
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "192.168.100.10/24"
          }
        ],
        "routes": [
          {
            "dst": "0.0.0.0/0",
            "gw": "192.168.100.1"
          }
        ],
        "dns": {
          "nameservers": ["8.8.8.8", "8.8.4.4"]
        }
      }
    }
```

## Network Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `sno_network_attachment_definition` | `""` | NAD to use (format: `namespace/name` or `name`) |
| `sno_vm_mac_address` | `""` | Specific MAC address (auto-generated if empty) |
| `sno_network_type` | `"pod"` | Network type (legacy, prefer using NAD) |

## Verification

### Check NAD Exists

```bash
# List all NADs in namespace
oc get network-attachment-definitions -n sno-clusters

# Describe specific NAD
oc describe network-attachment-definition bridge-network -n sno-clusters
```

### Verify VM Network Configuration

```bash
# Check VM definition
oc get vm sno-cluster-01-vm -n sno-clusters -o yaml | grep -A 20 networks

# Check VMI (running instance)
oc get vmi sno-cluster-01-vm -n sno-clusters -o yaml | grep -A 20 interfaces

# Check IP addresses
oc get vmi sno-cluster-01-vm -n sno-clusters -o jsonpath='{.status.interfaces}' | jq
```

### Test Connectivity

```bash
# Access VM console
virtctl console sno-cluster-01-vm -n sno-clusters

# Inside VM, check network
ip addr show
ip route show
ping -c 4 8.8.8.8
```

## Common Scenarios

### Scenario 1: Lab Environment (Default)

**Use Case:** Testing, development, simple lab setup

**Configuration:**
```yaml
# No NAD configuration needed - uses default pod network
```

### Scenario 2: Production VLAN Isolation

**Use Case:** Production SNO on dedicated VLAN

**Configuration:**
```yaml
sno_network_attachment_definition: "sno-production/vlan200-network"
sno_vm_mac_address: "52:54:00:aa:bb:cc"
```

**NAD Example:**
```yaml
# VLAN 200 for production
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan200-network
  namespace: sno-production
spec:
  config: |
    {
      "type": "macvlan",
      "master": "ens192",
      "mode": "bridge",
      "vlan": 200,
      "ipam": {"type": "dhcp"}
    }
```

### Scenario 3: Multiple SNO Clusters with Different Networks

**Configuration:**

```yaml
# sno-cluster-01 (VLAN 100)
sno_cluster_name: "sno-cluster-01"
sno_network_attachment_definition: "sno-clusters/vlan100-network"

# sno-cluster-02 (VLAN 200)
sno_cluster_name: "sno-cluster-02"
sno_network_attachment_definition: "sno-clusters/vlan200-network"
```

## Troubleshooting

### NAD Not Found

**Error:** `NetworkAttachmentDefinition xyz not found`

**Solutions:**
```bash
# Check if NAD exists
oc get net-attach-def -A | grep xyz

# Create NAD in correct namespace
oc apply -f nad.yaml

# Verify namespace in sno_network_attachment_definition matches
```

### VM Not Getting IP Address

**Symptoms:** VM boots but has no IP address

**Solutions:**
```bash
# Check DHCP is available on the network
# Verify CNI plugin logs
oc logs -n openshift-multus ds/multus

# Check if bridge/network exists on worker nodes
oc debug node/<node-name>
# Then: ip link show | grep br1
```

### Interface Not Attached

**Symptoms:** VM starts but network interface not attached

**Solutions:**
```bash
# Verify Multus is working
oc get pods -n openshift-multus

# Check NAD config is valid JSON
oc get net-attach-def bridge-network -n sno-clusters -o yaml

# Verify CNI plugin is installed
oc debug node/<node-name>
# Then: ls -la /opt/cni/bin/
```

### MAC Address Conflict

**Symptoms:** Network errors, duplicate IP

**Solutions:**
```yaml
# Set unique MAC address
sno_vm_mac_address: "52:54:00:aa:bb:cc"

# Or let it auto-generate (remove the variable)
```

## Best Practices

1. **Use NADs for production** - More control and isolation
2. **Plan IP address ranges** - Ensure DHCP ranges don't overlap
3. **Document MAC addresses** - Track assigned MACs for troubleshooting
4. **Test NAD first** - Create and test NAD with a simple VM before SNO
5. **Coordinate with network team** - Ensure VLANs and bridges exist on infrastructure
6. **Use DHCP reservations** - For predictable IP addresses
7. **Monitor CNI logs** - Watch for network plugin errors

## Reference

- [OpenShift Virtualization Networking](https://docs.openshift.com/container-platform/latest/virt/vm_networking/virt-networking-overview.html)
- [Multus CNI Documentation](https://github.com/k8snetworkplumbingwg/multus-cni)
- [Network Attachment Definitions](https://docs.openshift.com/container-platform/latest/networking/multiple_networks/understanding-multiple-networks.html)
