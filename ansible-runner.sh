#!/bin/bash
# Run Ansible playbooks using Podman container
# This eliminates the need to install Ansible on the host

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="localhost/ansible-runner:latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    print_error "Podman is required but not installed"
    echo "Install podman:"
    echo "  RHEL/Fedora: sudo dnf install -y podman"
    echo "  Ubuntu/Debian: sudo apt install -y podman"
    exit 1
fi

# Build the Ansible container image if it doesn't exist
build_image() {
    print_info "Checking for Ansible container image..."
    
    if podman image exists "$IMAGE_NAME"; then
        print_info "Ansible container image already exists"
        return 0
    fi
    
    print_info "Building Ansible container image..."
    cd "$SCRIPT_DIR"
    
    if [ -f "Containerfile" ]; then
        podman build -t "$IMAGE_NAME" -f Containerfile .
        print_info "Image built successfully"
    else
        print_error "Containerfile not found in $SCRIPT_DIR"
        exit 1
    fi
}

# Function to run Ansible playbook in container
run_ansible() {
    local playbook="$1"
    shift
    local extra_args="$@"
    
    if [ ! -f "$SCRIPT_DIR/$playbook" ]; then
        print_error "Playbook not found: $playbook"
        exit 1
    fi
    
    print_info "Running playbook: $playbook"
    
    # Ensure cache directory exists
    mkdir -p /tmp/openshift-installer-cache
    
    # Prepare volume mounts
    local volumes=(
        "-v" "$SCRIPT_DIR:/workspace:Z"
        "-v" "/tmp/openshift-installer-cache:/tmp/openshift-installer-cache:Z"
    )
    
    # Mount Podman socket if available (for ISO generation)
    local podman_socket=""
    if [ -S "/run/podman/podman.sock" ]; then
        podman_socket="/run/podman/podman.sock"
    elif [ -S "$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
        podman_socket="$XDG_RUNTIME_DIR/podman/podman.sock"
    elif [ -S "/run/user/$(id -u)/podman/podman.sock" ]; then
        podman_socket="/run/user/$(id -u)/podman/podman.sock"
    fi
    
    if [ -n "$podman_socket" ]; then
        volumes+=("-v" "$podman_socket:/run/podman/podman.sock:Z")
        volumes+=("-e" "PODMAN_SOCK_PATH=/run/podman/podman.sock")
    fi
    
    # Mount pull secret if it exists
    if [ -f "$SCRIPT_DIR/pull-secret.json" ]; then
        volumes+=("-v" "$SCRIPT_DIR/pull-secret.json:/workspace/pull-secret.json:Z")
    fi
    
    # Mount SSH key if it exists
    if [ -f "$SCRIPT_DIR/ssh-key.pub" ]; then
        volumes+=("-v" "$SCRIPT_DIR/ssh-key.pub:/workspace/ssh-key.pub:Z")
    fi
    
    # Determine authentication method and setup kubeconfig
    local auth_method=""
    local kubeconfig_path=""
    
    # Check for kubeconfig in various locations
    if [ -n "$KUBECONFIG" ] && [ -f "$KUBECONFIG" ]; then
        kubeconfig_path="$KUBECONFIG"
        auth_method="kubeconfig (from KUBECONFIG env)"
    elif [ -f "$HOME/.kube/config" ]; then
        kubeconfig_path="$HOME/.kube/config"
        auth_method="kubeconfig (from ~/.kube/config)"
    elif [ -f "$SCRIPT_DIR/kubeconfig" ]; then
        kubeconfig_path="$SCRIPT_DIR/kubeconfig"
        auth_method="kubeconfig (from ./kubeconfig)"
    fi
    
    # Mount kubeconfig if found
    if [ -n "$kubeconfig_path" ]; then
        volumes+=("-v" "$kubeconfig_path:/tmp/kubeconfig:Z")
        volumes+=("-e" "K8S_AUTH_KUBECONFIG=/tmp/kubeconfig")
        print_info "Using authentication: $auth_method"
    elif [ -n "$OPENSHIFT_TOKEN" ]; then
        auth_method="token (from OPENSHIFT_TOKEN env)"
        print_info "Using authentication: $auth_method"
    else
        print_warn "No authentication method found (neither kubeconfig nor OPENSHIFT_TOKEN)"
        print_warn "Set KUBECONFIG or OPENSHIFT_TOKEN, or place kubeconfig in ~/.kube/config"
    fi
    
    # Pass through environment variables
    local env_vars=(
        "-e" "OPENSHIFT_TOKEN=${OPENSHIFT_TOKEN:-}"
        "-e" "ASSISTED_OFFLINE_TOKEN=${ASSISTED_OFFLINE_TOKEN:-}"
    )
    
    # Run the container
    podman run --rm -it \
        "${volumes[@]}" \
        "${env_vars[@]}" \
        --network host \
        "$IMAGE_NAME" \
        -i /workspace/inventory/hosts \
        "$playbook" \
        $extra_args
    
    local ansible_exit_code=$?
    
    # Post-playbook hook: Embed ignition into ISOs for all clusters (deploy only)
    if [ "$playbook" = "deploy-sno.yml" ] && [ $ansible_exit_code -eq 0 ]; then
        if embed_ignition_isos; then
            # After embedding, upload ISOs to OpenShift
            print_info "Uploading embedded ISOs to OpenShift Virtualization..."
            podman run --rm -it \
                "${volumes[@]}" \
                "${env_vars[@]}" \
                --network host \
                "$IMAGE_NAME" \
                -i /workspace/inventory/hosts \
                "upload-iso.yml" \
                $extra_args
            
            if [ $? -eq 0 ]; then
                print_info "ISO upload completed successfully"
                
                # Attach ISO to VM and start it
                print_info "Attaching ISO to VM and starting..."
                podman run --rm -it \
                    "${volumes[@]}" \
                    "${env_vars[@]}" \
                    --network host \
                    "$IMAGE_NAME" \
                    -i /workspace/inventory/hosts \
                    "attach-iso.yml" \
                    $extra_args
                
                if [ $? -eq 0 ]; then
                    print_info "VM started successfully with embedded ignition ISO"
                else
                    print_error "Failed to attach ISO and start VM"
                    return 1
                fi
            else
                print_error "ISO upload failed"
                return 1
            fi
        else
            print_error "ISO embedding failed, skipping upload"
            return 1
        fi
    fi
    
    return $ansible_exit_code
}

# Function to embed ignition into ISOs for all clusters
embed_ignition_isos() {
    print_info "Checking for ISOs that need ignition embedding..."
    
    # Check if coreos-installer is available
    if ! command -v coreos-installer &> /dev/null; then
        print_warn "coreos-installer not found, installing..."
        
        # Detect package manager and install
        if command -v dnf &> /dev/null; then
            sudo dnf install -y coreos-installer
        elif command -v yum &> /dev/null; then
            sudo yum install -y coreos-installer
        elif command -v apt &> /dev/null; then
            print_error "coreos-installer not available in apt repositories"
            print_info "Installing from GitHub releases..."
            local installer_url="https://github.com/coreos/coreos-installer/releases/latest/download/coreos-installer"
            sudo curl -L "$installer_url" -o /usr/local/bin/coreos-installer
            sudo chmod +x /usr/local/bin/coreos-installer
        else
            print_error "Unable to install coreos-installer automatically"
            print_info "Please install manually from: https://github.com/coreos/coreos-installer"
            return 1
        fi
        
        if ! command -v coreos-installer &> /dev/null; then
            print_error "Failed to install coreos-installer"
            return 1
        fi
        
        print_info "coreos-installer installed successfully"
    fi
    
    # Find all cluster credentials directories
    local found_clusters=0
    for cluster_dir in "$SCRIPT_DIR"/credentials/*/; do
        if [ ! -d "$cluster_dir" ]; then
            print_warn "No cluster directories found in credentials/"
            continue
        fi
        
        local cluster_name=$(basename "$cluster_dir")
        local ignition_file="${cluster_dir}bootstrap-in-place-for-live-iso.ign"
        local iso_file="${cluster_dir}rhcos-live.iso"
        local embedded_marker="${cluster_dir}.iso-embedded"
        
        print_info "Checking cluster: $cluster_name"
        print_info "  Ignition file: $ignition_file (exists: $([ -f "$ignition_file" ] && echo 'yes' || echo 'no'))"
        print_info "  ISO file: $iso_file (exists: $([ -f "$iso_file" ] && echo 'yes' || echo 'no'))"
        print_info "  Marker file: $embedded_marker (exists: $([ -f "$embedded_marker" ] && echo 'yes' || echo 'no'))"
        
        # Skip if ignition or ISO doesn't exist
        if [ ! -f "$ignition_file" ]; then
            print_warn "Ignition file not found for cluster '$cluster_name', skipping"
            continue
        fi
        
        if [ ! -f "$iso_file" ]; then
            print_warn "ISO file not found for cluster '$cluster_name', skipping"
            continue
        fi
        
        found_clusters=$((found_clusters + 1))
        
        # Skip if already embedded
        if [ -f "$embedded_marker" ]; then
            print_info "ISO for cluster '$cluster_name' already has embedded ignition"
            continue
        fi
        
        print_info "Embedding ignition into ISO for cluster '$cluster_name'..."
        
        # Use coreos-installer directly on the host
        if coreos-installer iso ignition embed \
            -i "$ignition_file" \
            "$iso_file"; then
            
            # Mark as embedded
            touch "$embedded_marker"
            print_info "Successfully embedded ignition for cluster '$cluster_name'"
        else
            print_error "Failed to embed ignition for cluster '$cluster_name'"
            return 1
        fi
    done
    
    if [ $found_clusters -eq 0 ]; then
        print_warn "No clusters found with both ignition and ISO files"
        return 1
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    build           Build the Ansible container image
    deploy          Deploy SNO cluster on OpenShift Virtualization
    destroy         Destroy SNO cluster
    acm             Import deployed cluster into ACM
    operators       Deploy operators to SNO clusters via ACM policies
    deleteoperators Delete operator policies from ACM (does not uninstall operators)
    deployapp       Deploy Quarkus MySQL application via ACM and ArgoCD
    deleteapp       Delete Quarkus MySQL application from ACM and ArgoCD
    artifact        Collect cluster artifacts (kubeconfig, passwords, etc.)
    run <playbook>  Run a specific playbook
    shell           Open a shell in the Ansible container

Options:
    --limit <host>      Limit execution to specific host
    -v, --verbose       Verbose output
    --check             Run in check mode
    -h, --help          Show this help message

Examples:
    $0 build
    $0 deploy
    $0 deploy --limit sno-cluster-01 -v
    $0 destroy
    $0 operators
    $0 deleteoperators
    $0 deployapp
    $0 deleteapp
    $0 run deploy-sno.yml --check
    $0 shell

Environment Variables:
    OPENSHIFT_TOKEN         OpenShift API token (Option 1)
    KUBECONFIG              Path to kubeconfig file (Option 2 - Recommended)
    ASSISTED_OFFLINE_TOKEN  Red Hat Assisted Installer token (optional)

Authentication:
    The script will use kubeconfig if available (checked in order):
    1. $KUBECONFIG environment variable
    2. ~/.kube/config
    3. ./kubeconfig file in project directory
    
    If no kubeconfig is found, it falls back to token authentication via OPENSHIFT_TOKEN.

EOF
}

# Main command processing
case "${1:-}" in
    build)
        build_image
        ;;
    
    deploy)
        build_image
        shift
        run_ansible "deploy-sno.yml" "$@"
        ;;
    
    destroy)
        build_image
        shift
        run_ansible "destroy-sno.yml" "$@"
        ;;
    
    acm)
        build_image
        shift
        run_ansible "acm-import.yml" "$@"
        ;;
    
    operators)
        build_image
        shift
        run_ansible "acm-deploy-infrastructure.yml" "$@"
        ;;
    
    deleteoperators)
        build_image
        shift
        run_ansible "acm-delete-infrastructure.yml" "$@"
        ;;
    
    deployapp)
        build_image
        shift
        run_ansible "acm-deploy-application.yml" "$@"
        ;;
    
    deleteapp)
        build_image
        shift
        run_ansible "acm-delete-application.yml" "$@"
        ;;
    
    artifact)
        build_image
        shift
        run_ansible "collect-artifacts.yml" "$@"
        ;;
    
    run)
        if [ -z "$2" ]; then
            print_error "Please specify a playbook to run"
            usage
            exit 1
        fi
        build_image
        shift
        playbook="$1"
        shift
        run_ansible "$playbook" "$@"
        ;;
    
    shell)
        build_image
        print_info "Opening shell in Ansible container..."
        podman run --rm -it \
            -v "$SCRIPT_DIR:/workspace:Z" \
            -e "OPENSHIFT_TOKEN=${OPENSHIFT_TOKEN:-}" \
            -e "ASSISTED_OFFLINE_TOKEN=${ASSISTED_OFFLINE_TOKEN:-}" \
            --network host \
            --entrypoint /bin/bash \
            "$IMAGE_NAME"
        ;;
    
    -h|--help|help)
        usage
        ;;
    
    *)
        print_error "Unknown command: ${1:-}"
        echo ""
        usage
        exit 1
        ;;
esac
