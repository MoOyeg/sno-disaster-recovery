#!/bin/bash
# Helper script to create common NetworkAttachmentDefinitions

set -e

NAMESPACE="${1:-sno-clusters}"

echo "Creating NetworkAttachmentDefinitions in namespace: $NAMESPACE"

# Ensure namespace exists
oc create namespace "$NAMESPACE" 2>/dev/null || true

# Create bridge network
cat <<EOF | oc apply -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: bridge-network
  namespace: $NAMESPACE
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
EOF

echo "✓ Created bridge-network"

# Create VLAN 100 network
cat <<EOF | oc apply -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan100-network
  namespace: $NAMESPACE
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
EOF

echo "✓ Created vlan100-network"

echo ""
echo "NetworkAttachmentDefinitions created successfully!"
echo ""
echo "List all NADs:"
echo "  oc get network-attachment-definitions -n $NAMESPACE"
echo ""
echo "Use in SNO deployment:"
echo "  sno_network_attachment_definition: \"$NAMESPACE/bridge-network\""
echo "  or"
echo "  sno_network_attachment_definition: \"$NAMESPACE/vlan100-network\""
