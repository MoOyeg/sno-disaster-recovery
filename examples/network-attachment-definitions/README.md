# NetworkAttachmentDefinition Examples

This directory contains example NetworkAttachmentDefinition (NAD) resources for various network configurations.

## Overview

NetworkAttachmentDefinitions are used by Multus CNI to provide additional network interfaces to pods and VMs in OpenShift Virtualization.

## Examples Included

1. **bridge-network.yaml** - Bridge network for VM connectivity
2. **vlan-network.yaml** - VLAN-tagged network
3. **ovs-network.yaml** - OVS bridge network
4. **static-ip-network.yaml** - Network with static IP configuration

## Usage

### 1. Create the NetworkAttachmentDefinition

```bash
# Create namespace first
oc create namespace sno-clusters

# Apply the NAD
oc apply -f bridge-network.yaml
```

### 2. Configure SNO to Use the NAD

Edit your host_vars file (e.g., `inventory/host_vars/sno-cluster-01.yml`):

```yaml
sno_cluster_name: "sno-cluster-01"
sno_network_attachment_definition: "sno-clusters/bridge-network"
```

### 3. Deploy SNO

```bash
./ansible-runner.sh deploy --limit sno-cluster-01
```

## Verifying NAD

```bash
# List all NADs in namespace
oc get network-attachment-definitions -n sno-clusters

# Describe specific NAD
oc describe network-attachment-definition bridge-network -n sno-clusters

# Verify VM is using the NAD
oc get vmi -n sno-clusters -o yaml | grep -A 10 networks
```

## Important Notes

- The NAD must exist in the same namespace as the VM or be referenced with `namespace/name` format
- Ensure the underlying network infrastructure (bridge, VLAN, etc.) exists on worker nodes
- Some network types require specific CNI plugins to be installed
- For production use, consult your network team for proper VLAN IDs and network configuration
