# SNO Deployment - Podman/Container Architecture

## Overview

This automation uses a containerized approach to run Ansible, eliminating dependencies on the host system.

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Workstation                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Podman Container (ansible-runner)                    │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  - Ansible 2.14+                                │  │   │
│  │  │  - Python 3 + kubernetes/openshift packages    │  │   │
│  │  │  - Ansible Collections (k8s.core, etc.)        │  │   │
│  │  │  - OpenShift Install Binary                    │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                        │   │
│  │  Mounted Volumes:                                     │   │
│  │  - /workspace → Project directory                    │   │
│  │  - pull-secret.json → Red Hat credentials           │   │
│  │  - ssh-key.pub → SSH public key                     │   │
│  │                                                        │   │
│  │  Environment:                                         │   │
│  │  - OPENSHIFT_TOKEN (from host)                       │   │
│  │  - Network: host (access to OpenShift API)          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ HTTPS (6443)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              OpenShift Cluster (with OCP-V)                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: sno-clusters                             │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  VirtualMachine (KubeVirt)                      │  │   │
│  │  │  - 8 vCPU, 32GB RAM                             │  │   │
│  │  │  - 120GB Disk (PVC)                             │  │   │
│  │  │  - Boot from ISO (RHCOS)                        │  │   │
│  │  │  - Ignition config embedded                     │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                        │   │
│  │  Storage:                                             │   │
│  │  - PVC for VM disk (from StorageClass)              │   │
│  │  - DataVolume for ISO                                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ After Installation
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              Single Node OpenShift Cluster                   │
│  - Control Plane + Worker combined                           │
│  - Full OpenShift functionality                              │
│  - Accessible via API and Console                            │
└─────────────────────────────────────────────────────────────┘
```

## Workflow

### 1. Setup Phase
```bash
./setup.sh
```
- Checks for Podman
- Builds `ansible-runner` container image
- Validates prerequisites

### 2. Deployment Phase
```bash
./ansible-runner.sh deploy
```

**Inside Container:**
1. **Prerequisites Role**
   - Creates namespace on OCP cluster
   - Uploads pull secret as Secret
   - Validates storage class exists
   - Reads SSH public key

2. **Prepare Installation Role**
   - Generates install-config.yaml
   - Runs `openshift-install` to create ignition
   - Downloads/creates RHCOS ISO
   - Embeds ignition into ISO

3. **Create VM Role**
   - Creates DataVolume for ISO
   - Creates PVC for VM disk
   - Deploys VirtualMachine manifest
   - Waits for VM to start

4. **Monitor Installation Role**
   - Monitors bootstrap process
   - Waits for installation completion
   - Extracts kubeconfig and credentials
   - Saves to artifacts/

### 3. Access Phase
```bash
export KUBECONFIG=artifacts/sno-cluster/kubeconfig
oc get nodes
```

## Container Image Details

**Base Image:** UBI 9 (Red Hat Universal Base Image)

**Installed Components:**
- Python 3
- Ansible 2.14+
- Kubernetes Python client
- OpenShift Python client
- Ansible Collections:
  - kubernetes.core
  - community.general
  - ansible.posix

**Image Size:** ~500-600 MB

**Build Time:** 2-5 minutes (first time)

## Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| Project directory | /workspace | Playbooks, roles, inventory |
| pull-secret.json | /workspace/pull-secret.json | Red Hat credentials |
| ssh-key.pub | /workspace/ssh-key.pub | SSH public key |
| $KUBECONFIG (optional) | /tmp/kubeconfig | Existing cluster access |

## Environment Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| OPENSHIFT_TOKEN | Host env | Authenticate to OCP API |
| ASSISTED_OFFLINE_TOKEN | Host env | Red Hat Assisted Installer |
| KUBECONFIG | Host env | Path to kubeconfig |

## Network Configuration

The container runs with `--network host` to:
- Access OpenShift API endpoint
- Download installation media
- Communicate with cluster services

## Security Considerations

1. **SELinux Labels:** Volumes mounted with `:Z` flag for proper labeling
2. **Read-only mounts:** Where possible, mount files read-only
3. **No privileged mode:** Container runs without elevated privileges
4. **Credential isolation:** Secrets only passed via environment or mounts
5. **Temporary files:** Installation files stored in /tmp, cleaned after use

## Benefits of Container Approach

1. **No Host Dependencies**
   - No need to install Ansible locally
   - No Python package conflicts
   - No Ansible collection management

2. **Reproducibility**
   - Same environment for all users
   - Version-locked dependencies
   - Consistent behavior across systems

3. **Portability**
   - Works on any Linux with Podman
   - Easy to run in CI/CD pipelines
   - Simple to update (rebuild image)

4. **Isolation**
   - No impact on host system
   - Clean separation of concerns
   - Easy cleanup (remove container)

## Customization

### Building Custom Image

Modify `Containerfile` to:
- Add additional tools
- Install custom Ansible collections
- Include specific OpenShift client versions
- Add company-specific configurations

```dockerfile
FROM registry.access.redhat.com/ubi9/ubi:latest

# Add your customizations
RUN pip install your-custom-package
RUN ansible-galaxy collection install your.custom.collection

# ... rest of Containerfile
```

Then rebuild:
```bash
./ansible-runner.sh build
```

### Using Docker Instead of Podman

Edit `ansible-runner.sh` and replace `podman` with `docker`:
```bash
sed -i 's/podman/docker/g' ansible-runner.sh
```

## Troubleshooting

### Container won't start
```bash
# Check Podman status
podman info

# View logs
podman logs <container-id>

# Test manually
podman run --rm -it localhost/ansible-runner:latest /bin/bash
```

### Volume mount issues
```bash
# Check SELinux context
ls -Z pull-secret.json

# Relabel if needed
chcon -t container_file_t pull-secret.json
```

### Network connectivity
```bash
# Test from inside container
./ansible-runner.sh shell
curl -k https://api.your-cluster.example.com:6443/version
```
