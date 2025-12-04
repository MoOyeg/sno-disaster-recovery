# Single Node OpenShift on OpenShift Virtualization - Ansible Automation

This Ansible automation deploys a Single Node OpenShift (SNO) cluster on OpenShift Virtualization using KubeVirt.

## Overview

This automation handles the complete deployment lifecycle:
- Prerequisites validation (namespace, storage, secrets)
- OpenShift installation preparation (install-config, ISO generation)
- Virtual Machine creation with proper resources
- Installation monitoring and cluster validation
- Credential extraction and artifact storage

## Prerequisites

### On the Host OpenShift Cluster

1. **OpenShift Virtualization** installed and configured
2. **Storage Class** available for persistent volumes (e.g., OCS, NFS)
3. **Sufficient resources**:
   - CPU: 8+ cores available
   - Memory: 32+ GB available
   - Storage: 120+ GB available

### On the Control Node (Your Workstation/Bastion)

**No Ansible installation required!** This automation uses Podman to run Ansible in a container.

1. **Podman** installed (or Docker):
   ```bash
   # RHEL/Fedora/CentOS
   sudo dnf install -y podman
   
   # Ubuntu/Debian
   sudo apt install -y podman
   ```

2. **OpenShift CLI** (optional but recommended):
   - `oc` command-line tool for getting tokens
   - Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/

### Required Files

1. **Pull Secret** from Red Hat:
   - Download from: https://console.redhat.com/openshift/install/pull-secret
   - Save as: `pull-secret.json` in the project directory

2. **SSH Public Key**:
   - Generate: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa`
   - Save public key as: `ssh-key.pub` in the project directory

3. **OpenShift Access**:
   
   Choose one of these authentication methods:
   
   **Option A: Kubeconfig (Recommended)**
   ```bash
   # Use existing kubeconfig
   export KUBECONFIG=~/.kube/config
   
   # Or place in project directory
   cp ~/.kube/config ./kubeconfig
   ```
   
   **Option B: API Token**
   ```bash
   # Login to your OpenShift cluster
   oc login https://api.your-cluster.example.com:6443
   
   # Get token
   export OPENSHIFT_TOKEN=$(oc whoami -t)
   ```

## Configuration

### Basic Configuration

Edit `inventory/group_vars/all.yml`:

```yaml
# Authentication: Use kubeconfig OR token
# Priority: kubeconfig > token

# OpenShift API URL (required for token authentication)
openshift_api_url: "https://api.your-cluster.example.com:6443"

# Token authentication (set via OPENSHIFT_TOKEN env var)
# OR
# Kubeconfig authentication (set via KUBECONFIG env var or place at ./kubeconfig)

# SNO Cluster Configuration
sno_cluster_name: "sno-cluster"
sno_base_domain: "example.com"
sno_namespace: "sno-clusters"

# VM Specifications
sno_vm_cores: 8
sno_vm_memory: "32Gi"
sno_vm_disk_size: "120Gi"

# Storage
sno_storage_class: "ocs-storagecluster-ceph-rbd"

# OpenShift Version
sno_openshift_version: "4.14.8"
```

### Per-Cluster Configuration

Edit `inventory/host_vars/sno-cluster-01.yml` for cluster-specific settings:

```yaml
sno_cluster_name: "sno-cluster-01"
sno_base_domain: "lab.example.com"
sno_vm_cores: 16
sno_vm_memory: "64Gi"
```

## Usage

### 1. Initial Setup

Run the setup script to build the Ansible container image:

```bash
./setup.sh
```

This will:
- Check for Podman installation
- Build the Ansible runner container image
- Validate prerequisites

### 2. Prepare Credentials

```bash
# Option 1: Use kubeconfig (recommended)
export KUBECONFIG=~/.kube/config
# OR place kubeconfig in project directory
cp ~/.kube/config ./kubeconfig

# Option 2: Use OpenShift token
export OPENSHIFT_TOKEN=$(oc whoami -t)

# Ensure pull secret exists
ls -l pull-secret.json

# Ensure SSH key exists
ls -l ssh-key.pub
```

**Note:** The automation will automatically detect and use kubeconfig if available, otherwise it will fall back to token authentication.

### 3. Deploy SNO Cluster

```bash
# Deploy the cluster
./ansible-runner.sh deploy

# Deploy specific cluster
./ansible-runner.sh deploy --limit sno-cluster-01

# Deploy with verbose output
./ansible-runner.sh deploy -v

# Run in check mode (dry-run)
./ansible-runner.sh deploy --check
```

### 4. Monitor Installation

The playbook will:
1. Validate prerequisites
2. Generate installation files and ISO
3. Create the VM on OpenShift Virtualization
4. Boot from installation ISO
5. Monitor bootstrap and installation progress
6. Extract credentials when complete

Installation typically takes 30-60 minutes.

### 5. Access the Cluster

After successful installation, credentials are saved in:
```
artifacts/sno-cluster-01/
├── kubeconfig
├── kubeadmin-password
└── cluster-info.txt
```

Access the cluster:
```bash
# Export kubeconfig
export KUBECONFIG=artifacts/sno-cluster-01/kubeconfig

# Verify cluster
oc get nodes
oc get co

# Access console
# URL: https://console-openshift-console.apps.<cluster-name>.<base-domain>
# User: kubeadmin
# Password: contents of artifacts/sno-cluster-01/kubeadmin-password
```

### 6. Destroy Cluster

```bash
# Delete all cluster resources
./ansible-runner.sh destroy

# Delete specific cluster
./ansible-runner.sh destroy --limit sno-cluster-01
```

### 7. Advanced Usage

```bash
# Build/rebuild the Ansible container image
./ansible-runner.sh build

# Run a custom playbook
./ansible-runner.sh run examples/custom-deployment.yml

# Open a shell in the Ansible container for debugging
./ansible-runner.sh shell

# View all available options
./ansible-runner.sh --help
```

## Advanced Configuration

### Custom Network Configuration

Use NetworkAttachmentDefinitions for advanced networking:

```yaml
# In host_vars or group_vars
sno_network_attachment_definition: "sno-clusters/vlan100-network"
sno_vm_mac_address: "52:54:00:aa:bb:cc"  # Optional
```

**Steps:**

1. Create NetworkAttachmentDefinition:
   ```bash
   oc apply -f examples/network-attachment-definitions/vlan-network.yaml
   ```

2. Reference it in your configuration:
   ```yaml
   # inventory/host_vars/sno-cluster-01.yml
   sno_network_attachment_definition: "sno-clusters/vlan100-network"
   ```

3. Deploy:
   ```bash
   ./ansible-runner.sh deploy --limit sno-cluster-01
   ```

See `examples/network-attachment-definitions/` for NAD examples.

### Using Pre-Generated ISO

If you have a pre-generated ISO:

```yaml
sno_generate_iso: false
sno_iso_url: "http://fileserver.example.com/rhcos-sno.iso"
```

### Custom Install Config

Edit `roles/sno_prepare_installation/templates/install-config.yaml.j2` to customize:
- Network CIDR ranges
- Proxy settings
- Additional manifests
- Platform-specific settings

## Troubleshooting

### Authentication Issues

**Using kubeconfig:**
```bash
# Verify kubeconfig is accessible
echo $KUBECONFIG
cat $KUBECONFIG

# Test connection
oc get nodes

# Inside container
./ansible-runner.sh shell
ls -l /tmp/kubeconfig
```

**Using token:**
```bash
# Verify token is set
echo $OPENSHIFT_TOKEN

# Test token
oc whoami

# Refresh token if expired
export OPENSHIFT_TOKEN=$(oc whoami -t)
```

### Check VM Status

```bash
oc get vm -n sno-clusters
oc get vmi -n sno-clusters
```

### Access VM Console

```bash
virtctl console <vm-name> -n sno-clusters
```

### View Installation Logs

```bash
# On the control node
tail -f /tmp/sno-install-<cluster-name>/.openshift_install.log
```

### Common Issues

1. **Storage class not found**:
   - Verify storage class exists: `oc get sc`
   - Update `sno_storage_class` variable

2. **Insufficient resources**:
   - Check available resources on worker nodes
   - Reduce `sno_vm_cores` and `sno_vm_memory` if needed

3. **Network connectivity**:
   - Access VM console to check progress
   - Verify NetworkAttachmentDefinition is correct (if using custom networking)
   - Check network connectivity from VM

4. **NetworkAttachmentDefinition not found**:
   - Verify NAD exists: `oc get network-attachment-definitions -n <namespace>`
   - Check NAD name format: `namespace/name` or just `name` (uses VM namespace)
   - Create NAD using examples in `examples/network-attachment-definitions/`

5. **Bootstrap timeout**:
   - Access VM console to check progress
   - Verify network connectivity
   - Check ignition configuration

## Project Structure

```
.
├── Containerfile                        # Ansible container image definition
├── ansible-runner.sh                    # Podman-based Ansible runner (main interface)
├── setup.sh                            # Initial setup script
├── ansible.cfg                          # Ansible configuration
├── requirements.yml                     # Ansible collection requirements
├── deploy-sno.yml                       # Main deployment playbook
├── destroy-sno.yml                      # Cleanup playbook
├── inventory/
│   ├── hosts                           # Inventory file
│   ├── group_vars/
│   │   └── all.yml                     # Global variables
│   └── host_vars/
│       └── sno-cluster-01.yml          # Per-cluster variables
├── roles/
│   ├── sno_prerequisites/              # Prerequisites validation
│   ├── sno_prepare_installation/       # Installation preparation
│   ├── sno_create_vm/                  # VM creation
│   └── sno_monitor_installation/       # Installation monitoring
├── examples/
│   ├── custom-deployment.yml           # Custom deployment example
│   ├── multi-cluster-deployment.yml    # Multiple clusters
│   ├── network-attachment-definitions/ # NAD examples for custom networking
│   └── host_vars/                      # Example host configurations
└── artifacts/                           # Generated cluster credentials
    └── <cluster-name>/
        ├── kubeconfig
        ├── kubeadmin-password
        └── cluster-info.txt
```

## Security Considerations

1. **Protect credentials**:
   - Never commit `pull-secret.json` or `ssh-key.pub` to version control
   - Use `.gitignore` for sensitive files
   - Restrict access to `artifacts/` directory

2. **OpenShift token**:
   - Use environment variables for tokens
   - Rotate tokens regularly
   - Use service accounts for automation

3. **Network security**:
   - Use NetworkPolicies to isolate SNO VM
   - Configure proper firewall rules
   - Use TLS for all communications

## Why Podman-based?

This automation uses Podman to run Ansible in a container, providing several benefits:

1. **No Local Installation**: No need to install Ansible, Python packages, or collections on your system
2. **Consistency**: Same environment across all users and systems
3. **Isolation**: Dependencies don't conflict with system packages
4. **Portability**: Works on any system with Podman/Docker
5. **Easy Updates**: Rebuild the container to update dependencies

## Troubleshooting

### Podman Issues

**Permission denied errors**:
```bash
# Run podman in rootless mode (default) or with sudo
sudo ./ansible-runner.sh deploy
```

**SELinux issues with volume mounts**:
- The `:Z` flag is used automatically for proper SELinux labeling
- If issues persist, check `sudo ausearch -m avc -ts recent`

**Image build fails**:
```bash
# Rebuild with no cache
podman build --no-cache -t localhost/ansible-runner:latest -f Containerfile .
```

### Container environment

**Need to debug inside the container**:
```bash
./ansible-runner.sh shell
# Now you're inside the container
ansible --version
ls -la /workspace
```

## Support and Contributions

For issues, questions, or contributions:
- Review the OpenShift documentation: https://docs.openshift.com
- Check OpenShift Virtualization docs: https://docs.openshift.com/container-platform/latest/virt/about-virt.html
- Review Single Node OpenShift documentation

## License

This automation is provided as-is for educational and operational purposes.
