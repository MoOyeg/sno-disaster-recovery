#!/bin/bash
# Quick setup script for SNO deployment using Podman

set -e

echo "=== SNO on OpenShift Virtualization - Setup ==="

# Check prerequisites
echo "Checking prerequisites..."

# Check Podman
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is required"
    echo "Install with:"
    echo "  RHEL/Fedora: sudo dnf install -y podman"
    echo "  Ubuntu/Debian: sudo apt install -y podman"
    exit 1
fi

echo "✓ Podman found: $(podman --version)"

# Check oc CLI (optional but recommended)
if ! command -v oc &> /dev/null; then
    echo "Warning: oc CLI not found (optional)"
    echo "Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
else
    echo "✓ OpenShift CLI found: $(oc version --client | head -n1)"
fi

# Build Ansible container image
echo ""
echo "Building Ansible container image..."
./ansible-runner.sh build

# Check for pull secret
if [ ! -f "pull-secret.json" ]; then
    echo ""
    echo "Warning: pull-secret.json not found"
    echo "Download from: https://console.redhat.com/openshift/install/pull-secret"
    echo "Save as: pull-secret.json"
fi

# Check for SSH key
if [ ! -f "ssh-key.pub" ]; then
    echo ""
    echo "Warning: ssh-key.pub not found"
    echo "Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
    echo "Copy public key: cp ~/.ssh/id_rsa.pub ssh-key.pub"
fi

# Check OpenShift token
if [ -z "$OPENSHIFT_TOKEN" ]; then
    echo ""
    echo "Warning: OPENSHIFT_TOKEN not set"
    echo "Set with: export OPENSHIFT_TOKEN=\$(oc whoami -t)"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit inventory/group_vars/all.yml with your configuration"
echo "2. Ensure pull-secret.json exists"
echo "3. Ensure ssh-key.pub exists"
echo "4. Set OPENSHIFT_TOKEN: export OPENSHIFT_TOKEN=\$(oc whoami -t)"
echo "5. Run: ./ansible-runner.sh deploy"
echo ""
echo "Additional commands:"
echo "  ./ansible-runner.sh deploy --limit sno-cluster-01  # Deploy specific cluster"
echo "  ./ansible-runner.sh deploy -v                      # Verbose output"
echo "  ./ansible-runner.sh destroy                        # Destroy cluster"
echo "  ./ansible-runner.sh shell                          # Open Ansible container shell"
echo ""
