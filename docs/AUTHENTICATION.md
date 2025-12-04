# Authentication Configuration Examples

## Overview

The automation supports two authentication methods to connect to the OpenShift cluster:

1. **Kubeconfig** (Recommended) - More secure, supports multiple contexts
2. **API Token** - Simple, good for automation/CI

## Kubeconfig Authentication (Recommended)

### Using Default Kubeconfig Location

```bash
# Login to your cluster
oc login https://api.your-cluster.example.com:6443

# Kubeconfig is automatically created at ~/.kube/config
# No additional configuration needed

# Run deployment
./ansible-runner.sh deploy
```

### Using Custom Kubeconfig Location

```bash
# Set KUBECONFIG environment variable
export KUBECONFIG=/path/to/your/kubeconfig

# Run deployment
./ansible-runner.sh deploy
```

### Using Kubeconfig in Project Directory

```bash
# Copy kubeconfig to project directory
cp ~/.kube/config ./kubeconfig

# Run deployment (will auto-detect ./kubeconfig)
./ansible-runner.sh deploy
```

### Multiple Contexts

```bash
# Login to the cluster hosting OpenShift Virtualization
oc login https://api.host-cluster.example.com:6443

# Verify current context
oc config current-context

# Run deployment
./ansible-runner.sh deploy
```

## Token Authentication

### Basic Token Authentication

```bash
# Login to your cluster
oc login https://api.your-cluster.example.com:6443

# Get and export token
export OPENSHIFT_TOKEN=$(oc whoami -t)

# Run deployment
./ansible-runner.sh deploy
```

### Using Service Account Token

```bash
# Create service account
oc create sa sno-deployer -n default

# Grant cluster-admin (or appropriate permissions)
oc adm policy add-cluster-role-to-user cluster-admin -z sno-deployer -n default

# Get service account token
export OPENSHIFT_TOKEN=$(oc sa get-token sno-deployer -n default)

# Update API URL in inventory/group_vars/all.yml
# openshift_api_url: "https://api.your-cluster.example.com:6443"

# Run deployment
./ansible-runner.sh deploy
```

### Long-lived Token

```bash
# Create a long-lived service account
oc create sa sno-automation -n openshift-infra

# Create token secret
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: sno-automation-token
  namespace: openshift-infra
  annotations:
    kubernetes.io/service-account.name: sno-automation
type: kubernetes.io/service-account-token
EOF

# Wait for token to be generated
sleep 5

# Get the token
export OPENSHIFT_TOKEN=$(oc get secret sno-automation-token -n openshift-infra -o jsonpath='{.data.token}' | base64 -d)

# Use the token
./ansible-runner.sh deploy
```

## Authentication Priority

The automation checks authentication in this order:

1. **K8S_AUTH_KUBECONFIG** environment variable (set by ansible-runner.sh)
2. **OPENSHIFT_TOKEN** environment variable
3. Falls back to error if neither is available

## Variable Configuration

### For Kubeconfig Authentication

In `inventory/group_vars/all.yml`:
```yaml
# API URL is optional when using kubeconfig
# It will be extracted from the kubeconfig context

# Certificate validation (optional)
openshift_validate_certs: false
```

### For Token Authentication

In `inventory/group_vars/all.yml`:
```yaml
# API URL is REQUIRED for token authentication
openshift_api_url: "https://api.your-cluster.example.com:6443"

# Token is pulled from environment variable
openshift_token: "{{ lookup('env', 'OPENSHIFT_TOKEN') }}"

# Certificate validation
openshift_validate_certs: false
```

## Best Practices

### For Development

```bash
# Use kubeconfig with your regular user account
oc login https://api.cluster.example.com:6443 -u developer
./ansible-runner.sh deploy
```

### For CI/CD Pipelines

```bash
# Use service account with scoped permissions
export OPENSHIFT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
export OPENSHIFT_API_URL="https://kubernetes.default.svc"
./ansible-runner.sh deploy
```

### For Production

```bash
# Use kubeconfig with service account
# Create kubeconfig for service account
SA_TOKEN=$(oc sa get-token sno-deployer -n default)
API_SERVER=$(oc whoami --show-server)

cat > kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${API_SERVER}
    insecure-skip-tls-verify: true
  name: target-cluster
contexts:
- context:
    cluster: target-cluster
    user: sno-deployer
  name: sno-deployer-context
current-context: sno-deployer-context
users:
- name: sno-deployer
  user:
    token: ${SA_TOKEN}
EOF

export KUBECONFIG=./kubeconfig
./ansible-runner.sh deploy
```

## Required Permissions

The service account or user needs these permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sno-deployer
rules:
  # Namespace management
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "create", "delete"]
  
  # VM and virtualization resources
  - apiGroups: ["kubevirt.io"]
    resources: ["virtualmachines", "virtualmachineinstances"]
    verbs: ["get", "list", "create", "delete", "watch"]
  
  # Storage resources
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "create", "delete"]
  
  - apiGroups: ["cdi.kubevirt.io"]
    resources: ["datavolumes"]
    verbs: ["get", "list", "create", "delete", "watch"]
  
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list"]
  
  # Secrets for pull secret
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create", "delete"]
  
  # Services (for ISO hosting)
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "create", "delete"]
```

## Troubleshooting

### Kubeconfig Not Found

```bash
# Check if kubeconfig exists
ls -la ~/.kube/config
echo $KUBECONFIG

# Verify kubeconfig is valid
oc --kubeconfig ~/.kube/config get nodes

# Check inside container
./ansible-runner.sh shell
ls -l /tmp/kubeconfig
```

### Token Expired

```bash
# Refresh token
export OPENSHIFT_TOKEN=$(oc whoami -t)

# Or login again
oc login https://api.cluster.example.com:6443
export OPENSHIFT_TOKEN=$(oc whoami -t)
```

### Permission Denied

```bash
# Check current user permissions
oc auth can-i create virtualmachines.kubevirt.io -n sno-clusters

# Check all permissions
oc auth can-i --list

# Grant necessary permissions
oc adm policy add-cluster-role-to-user sno-deployer $(oc whoami)
```

### Multiple Clusters

```bash
# List available contexts
oc config get-contexts

# Switch to the correct cluster
oc config use-context host-cluster-admin

# Verify
oc cluster-info

# Run deployment
./ansible-runner.sh deploy
```
