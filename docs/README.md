# Documentation Index

This directory contains comprehensive documentation for deploying Single Node OpenShift (SNO) clusters on OpenShift Virtualization.

## Quick Navigation

### Getting Started

- **[Main README](../README.md)** ⭐ Start here
  - Complete deployment guide
  - Prerequisites and setup
  - Configuration examples
  - Troubleshooting

- **[Architecture Diagram](../architecture-diagram.drawio)** 📐 Visual reference
  - System architecture
  - Component relationships
  - Data flows

### Advanced Topics

- **[VolSync Failover Blog](VOLSYNC-FAILOVER-BLOG.md)** 🔄 Disaster Recovery
  - Automated DR with VolSync + ACM
  - Zero-touch failover/failback
  - Policy-driven replication
  - Step-by-step scenarios

- **[Authentication Guide](AUTHENTICATION.md)** 🔐 Security
  - Cluster authentication
  - Certificate management
  - Access control

- **[Networking Guide](NETWORKING.md)** 🌐 Advanced networking
  - Network configurations
  - Network attachment definitions
  - Multi-network setups

## Documentation Overview

### For New Users

**Question: "How do I get started?"**
→ Follow the main [README.md](../README.md)

**Question: "How do I set up disaster recovery?"**
→ Read [VolSync Failover Blog](VOLSYNC-FAILOVER-BLOG.md)

**Question: "How do I configure networking?"**
→ See [Networking Guide](NETWORKING.md)

### For Operators

**Deployment:**
1. [README.md](../README.md) - Complete deployment guide
2. [Configuration Examples](../inventory/host_vars/) - Cluster-specific settings
3. [Troubleshooting](../README.md#troubleshooting) - Common issues

**Disaster Recovery:**
- [VolSync Failover Blog](VOLSYNC-FAILOVER-BLOG.md) - Automated DR setup
- [ACM Policies](../acm-policy-volsync-automate.yaml) - Policy definitions

**Security:**
- [Authentication Guide](AUTHENTICATION.md) - Access control
- [README.md - Security](../README.md#security) - Security best practices

### For Developers

**Architecture:**
- [Architecture Diagram](../architecture-diagram.drawio) - Visual representation
- [VolSync Blog Diagrams](diagrams/) - DR architecture diagrams

**Integration:**
- [ACM Integration](../acm-deploy-infrastructure.yml) - Operator deployment
- [GitOps Setup](../acm-deploy-application.yml) - Application deployment

## Document Summaries

### VolSync Failover Blog (800+ lines)

**Purpose:** Comprehensive guide to automated disaster recovery using VolSync and ACM

**Key Sections:**
- Architecture overview with diagrams
- 6 ACM policies explained in detail
- Cross-cluster data replication
- Zero-touch failover scenarios
- Failback procedures
- Technical deep dive (hub templates, ManagedClusterView)
- Troubleshooting and debugging
- Performance considerations

**Best For:** Anyone implementing disaster recovery with VolSync

---

### Authentication Guide

**Purpose:** Secure cluster access and authentication setup

**Key Sections:**
- Authentication methods
- Certificate management
- User and service account configuration
- RBAC setup

**Best For:** Security-focused deployments

---

### Networking Guide

**Purpose:** Advanced networking configurations for SNO clusters

**Key Sections:**
- Network attachment definitions
- Bridge networks
- OVS networks
- VLAN configurations
- Static IP assignments
- Multi-network pod configuration

**Best For:** Complex networking requirements

## Related Documentation

### In Main Directory

- [README.md](../README.md) - Main project documentation
- [architecture-diagram.drawio](../architecture-diagram.drawio) - Architecture visualization
- [QUICKSTART.md](../QUICKSTART.md) - Quick start guide

### Configuration Files

- `inventory/group_vars/all.yml` - Global configuration
- `inventory/host_vars/sno-cluster.yml` - Example cluster configuration
- `inventory/host_vars/*.yml` - Cluster-specific configuration

### Playbooks

- `deploy-sno.yml` - SNO cluster deployment
- `acm-deploy-infrastructure.yml` - ACM and operator deployment
- `acm-deploy-application.yml` - Application deployment via GitOps
- `acm-policy-volsync-automate.yaml` - VolSync DR policies

## Quick Reference Commands

### Deploy SNO Cluster
```bash
./ansible-runner.sh deploy --limit sno-cluster
```

### Deploy Operators (ACM, MetalLB, LVM, GitOps, VolSync)
```bash
./ansible-runner.sh operators
```

### Deploy Application with DR
```bash
./ansible-runner.sh deployapp
```

### Cleanup
```bash
./ansible-runner.sh deleteapp
./ansible-runner.sh destroy --limit sno-cluster
```

## Common Scenarios

### Scenario 1: Deploy Single SNO Cluster

**Documents to read:**
1. [README.md - Quick Start](../README.md)
2. [QUICKSTART.md](../QUICKSTART.md)

**Commands:**
```bash
./ansible-runner.sh deploy --limit sno-cluster
```

---

### Scenario 2: Deploy Multiple SNO Clusters with DR

**Documents to read:**
1. [VolSync Failover Blog](VOLSYNC-FAILOVER-BLOG.md)
2. [README.md - Complete Deployment](../README.md#complete-deployment-examples)

**Commands:**
```bash
./ansible-runner.sh deploy --limit sno-cluster
./ansible-runner.sh deploy --limit sno-cluster2
./ansible-runner.sh operators
./ansible-runner.sh deployapp
```

---

### Scenario 3: Configure Advanced Networking

**Documents to read:**
1. [Networking Guide](NETWORKING.md)
2. [Network Attachment Definitions Examples](../examples/network-attachment-definitions/)

**Key Actions:**
- Review NAD examples (bridge, OVS, VLAN)
- Configure host_vars with network settings
- Apply NADs after deployment
- Validate connectivity

---

### Scenario 4: Troubleshooting Deployment

**Documents to read:**
1. [README.md - Troubleshooting](../README.md#troubleshooting)
2. [VolSync Blog - Troubleshooting](VOLSYNC-FAILOVER-BLOG.md#troubleshooting)

**Common Checks:**
- Verify prerequisites (OCP version, storage)
- Check VM status and console logs
- Validate DNS resolution
- Review installation logs in artifacts/
- Check policy compliance in ACM

## Support and Community

### Getting Help

1. **Check documentation** - Most questions are answered in these guides
2. **Review examples** - See configuration examples in `inventory/host_vars/`
3. **Read troubleshooting** - Common issues and solutions documented
4. **Check logs** - Artifacts directory contains cluster logs

### Contributing

If you find issues or have improvements:
1. Document the issue clearly
2. Include configuration examples
3. Provide error messages or logs
4. Suggest solutions if available

## Document Maintenance

### Last Updated
- Main README: 2026
- VolSync Failover Blog: 2026
- Networking Guide: 2024
- Authentication Guide: 2024

### Version Compatibility
- OpenShift: 4.14+ (tested with 4.20.2)
- OpenShift Virtualization: 4.14+
- ACM: 2.9+
- VolSync: 0.9+
- Ansible: 2.14+
- Python: 3.9+

## Feedback

Documentation is continuously improved. If you have suggestions:
- Unclear sections
- Missing information
- Incorrect instructions
- Additional examples needed

Please provide feedback with specific page/section references.

---

**Last Updated:** 2024  
**Maintainers:** SNO Cluster Automation Team
