#!/bin/bash
# Makefile-style shortcuts for common operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "${1:-help}" in
    setup)
        echo "Running initial setup..."
        ./setup.sh
        ;;
    
    deploy)
        echo "Deploying SNO cluster..."
        ./ansible-runner.sh deploy "${@:2}"
        ;;
    
    destroy)
        echo "Destroying SNO cluster..."
        ./ansible-runner.sh destroy "${@:2}"
        ;;
    
    check)
        echo "Checking deployment (dry-run)..."
        ./ansible-runner.sh deploy --check "${@:2}"
        ;;
    
    shell)
        echo "Opening Ansible container shell..."
        ./ansible-runner.sh shell
        ;;
    
    build)
        echo "Building Ansible container image..."
        ./ansible-runner.sh build
        ;;
    
    clean)
        echo "Cleaning up temporary files..."
        rm -rf /tmp/sno-install-*
        echo "Cleaned temporary installation files"
        ;;
    
    status)
        if [ -z "$OPENSHIFT_TOKEN" ]; then
            echo "Error: OPENSHIFT_TOKEN not set"
            exit 1
        fi
        echo "Checking cluster status..."
        ./ansible-runner.sh shell -c "oc get vm -n sno-clusters 2>/dev/null || echo 'No VMs found'"
        ;;
    
    help|*)
        cat << 'EOF'
SNO Deployment Shortcuts

Usage: ./run.sh <command> [options]

Commands:
    setup       Run initial setup (build container, check prerequisites)
    deploy      Deploy SNO cluster
    destroy     Destroy SNO cluster
    check       Run deployment in check mode (dry-run)
    shell       Open shell in Ansible container
    build       Build/rebuild Ansible container image
    clean       Clean up temporary files
    status      Check cluster status
    help        Show this help message

Examples:
    ./run.sh setup
    ./run.sh deploy
    ./run.sh deploy --limit sno-cluster-01 -v
    ./run.sh check
    ./run.sh destroy
    ./run.sh shell
    ./run.sh clean

Environment Variables:
    OPENSHIFT_TOKEN    Required for cluster operations
    
Quick Start:
    1. ./run.sh setup
    2. Edit inventory/group_vars/all.yml
    3. export OPENSHIFT_TOKEN=$(oc whoami -t)
    4. ./run.sh deploy

EOF
        ;;
esac
