# Quick Start Guide - SNO on OpenShift Virtualization

## Prerequisites
- Podman installed on your workstation
- Access to an OpenShift cluster with OpenShift Virtualization
- Pull secret from Red Hat
- SSH key pair

## 5-Minute Setup

### 1. Initial Setup
```bash
# Run setup script
./setup.sh
```

### 2. Configure Credentials
```bash
# Option 1: Use kubeconfig (recommended)
export KUBECONFIG=~/.kube/config
# Test: oc get nodes

# Option 2: Use token
export OPENSHIFT_TOKEN=$(oc whoami -t)

# Ensure pull secret exists
cp ~/downloads/pull-secret.json .

# Ensure SSH key exists
cp ~/.ssh/id_rsa.pub ssh-key.pub
```

### 3. Configure Cluster
Edit `inventory/group_vars/all.yml`:
```yaml
# API URL (required only for token auth)
openshift_api_url: "https://api.your-cluster.example.com:6443"

sno_cluster_name: "sno-cluster"
sno_base_domain: "example.com"
sno_storage_class: "ocs-storagecluster-ceph-rbd"  # Adjust for your storage
```

**Note:** Authentication is automatic - uses kubeconfig if found, otherwise uses token.

### 4. Deploy
```bash
./ansible-runner.sh deploy
```

### 5. Access Your Cluster
After 30-60 minutes:
```bash
# Credentials are saved in:
cat artifacts/sno-cluster/kubeadmin-password

# Use the kubeconfig:
export KUBECONFIG=$(pwd)/artifacts/sno-cluster/kubeconfig
oc get nodes
```

## Common Commands

```bash
# Deploy
./ansible-runner.sh deploy

# Deploy with verbose output
./ansible-runner.sh deploy -v

# Deploy specific cluster
./ansible-runner.sh deploy --limit sno-cluster-01

# Destroy cluster
./ansible-runner.sh destroy

# Debug in container
./ansible-runner.sh shell

# Rebuild container image
./ansible-runner.sh build
```

## Troubleshooting

### Check VM status
```bash
oc get vm -n sno-clusters
oc get vmi -n sno-clusters
```

### Access VM console
```bash
virtctl console <vm-name> -n sno-clusters
```

### Check Podman
```bash
podman images | grep ansible-runner
podman ps
```

## Next Steps
- Review full documentation in README.md
- Customize VM specs in inventory variables
- Deploy multiple clusters using host_vars
