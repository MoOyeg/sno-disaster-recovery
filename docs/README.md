# Documentation Index

This directory contains comprehensive documentation for deploying Single Node OpenShift (SNO) clusters on OpenShift Virtualization and AWS.

## Quick Navigation

### Getting Started

- **[Platform Comparison Guide](PLATFORM-COMPARISON.md)** ⭐ Start here
  - Compare OpenShift Virtualization vs AWS
  - Decision matrix and recommendations
  - Cost comparison
  - Hybrid DR approach

- **[AWS Quick Start](QUICKSTART-AWS.md)** 🚀 Deploy in < 1 hour
  - Streamlined AWS deployment
  - Copy-paste commands
  - Complete prerequisites setup
  - Quick verification steps

### Detailed Guides

- **[AWS Deployment Guide](AWS-DEPLOYMENT-GUIDE.md)** 📘 Comprehensive reference
  - Complete AWS setup instructions
  - IAM permissions and prerequisites
  - VPC and networking configuration
  - Finding RHCOS AMI IDs
  - Route53 DNS setup
  - Troubleshooting guide
  - Cost optimization strategies
  - Cleanup procedures

- **[AWS Feature Summary](AWS-FEATURE-SUMMARY.md)** 📋 Technical documentation
  - Implementation details
  - Configuration files modified
  - Integration with existing features
  - Testing recommendations
  - Known limitations
  - Future enhancements

## Documentation Overview

### For New Users

**Question: "Which platform should I use?"**
→ Read [Platform Comparison Guide](PLATFORM-COMPARISON.md)

**Question: "How do I get started with AWS?"**
→ Follow [AWS Quick Start](QUICKSTART-AWS.md)

**Question: "I have an OpenShift cluster already"**
→ See main [README.md](../README.md) for OpenShift Virtualization

### For AWS Users

**Prerequisites and Setup:**
1. [Platform Comparison](PLATFORM-COMPARISON.md) - Understand the platform choice
2. [AWS Quick Start](QUICKSTART-AWS.md) - Rapid deployment guide
3. [AWS Deployment Guide](AWS-DEPLOYMENT-GUIDE.md) - Detailed setup and configuration

**Troubleshooting:**
- [AWS Deployment Guide - Troubleshooting Section](AWS-DEPLOYMENT-GUIDE.md#troubleshooting)
- [AWS Deployment Guide - Common Issues](AWS-DEPLOYMENT-GUIDE.md#common-issues)

**Cost Management:**
- [AWS Deployment Guide - Cost Optimization](AWS-DEPLOYMENT-GUIDE.md#cost-optimization)
- [Platform Comparison - Cost Comparison](PLATFORM-COMPARISON.md#cost-comparison)

### For OpenShift Virtualization Users

**Prerequisites and Setup:**
- See main [README.md](../README.md)

**Configuration:**
- See [README.md - Configuration Section](../README.md#configuration)

### For Developers

**Architecture:**
- [Architecture Diagram](../architecture-diagram.drawio) - Visual representation
- [AWS Feature Summary](AWS-FEATURE-SUMMARY.md) - Technical implementation

**Integration:**
- [AWS Feature Summary - Integration Section](AWS-FEATURE-SUMMARY.md#integration-with-existing-features)

## Document Summaries

### Platform Comparison Guide (600+ lines)

**Purpose:** Help users choose between OpenShift Virtualization and AWS

**Key Sections:**
- Quick decision matrix with visual indicators
- Detailed comparison of features, costs, and capabilities
- When to use each platform
- Advantages and disadvantages
- Cost breakdown for both platforms
- Hybrid approach (recommended for DR)
- Decision guide with questions
- Migration considerations between platforms
- Recommendation matrix by scenario

**Best For:** Anyone evaluating deployment options

---

### AWS Quick Start (400+ lines)

**Purpose:** Get from zero to running SNO on AWS in under an hour

**Key Sections:**
- Prerequisites checklist
- Quick AWS resource setup (VPC, subnet, security group)
- Automated infrastructure creation with copy-paste commands
- RHCOS AMI discovery
- Cluster configuration
- Authentication setup
- Deployment steps
- Monitoring progress
- Verification
- Cleanup procedures
- Quick troubleshooting

**Best For:** Users who want rapid AWS deployment

---

### AWS Deployment Guide (850+ lines)

**Purpose:** Comprehensive reference for AWS deployments

**Key Sections:**
- **Prerequisites:** IAM permissions, AWS CLI setup, account requirements
- **AWS Resource Preparation:** VPC, subnets, security groups, key pairs, Route53
- **Configuration:** Host variables, inventory setup, AWS-specific settings
- **Deployment:** Step-by-step deployment instructions
- **Verification:** Cluster access, console access, SSH access
- **Troubleshooting:** Instance launch issues, DNS issues, network connectivity, storage issues
- **Cost Optimization:** Instance sizing, EBS optimization, cost-saving tips, monthly estimates
- **Cleanup:** Manual cleanup, automated scripts

**Best For:** Users who need detailed reference and troubleshooting

---

### AWS Feature Summary (700+ lines)

**Purpose:** Technical documentation for developers and maintainers

**Key Sections:**
- Changes made (playbooks, scripts, configurations)
- Technical details (AWS resources, device naming, integration)
- Workflow examples
- Testing recommendations
- Known limitations
- Future enhancements
- Dependencies
- Verification checklist

**Best For:** Developers, maintainers, and technical reviewers

## Related Documentation

### In Main Directory

- [README.md](../README.md) - Main project documentation
- [architecture-diagram.drawio](../architecture-diagram.drawio) - Architecture visualization

### Configuration Files

- `inventory/group_vars/all.yml` - Global configuration
- `inventory/host_vars/sno-aws-example.yml` - AWS example configuration
- `inventory/host_vars/*.yml` - Cluster-specific configuration

### Playbooks

- `deploy-sno.yml` - OpenShift Virtualization deployment
- `deploy-sno-aws.yml` - AWS deployment
- `acm-deploy-infrastructure.yml` - ACM policy deployment
- `acm-deploy-application.yml` - Application deployment via GitOps

## Quick Reference Commands

### OpenShift Virtualization
```bash
./ansible-runner.sh deploy --limit sno-cluster-01
```

### AWS
```bash
./ansible-runner.sh deployaws --limit sno-aws-01
```

### Operators (Both Platforms)
```bash
./ansible-runner.sh operators
```

### Application (Both Platforms)
```bash
./ansible-runner.sh deployapp
```

## Common Scenarios

### Scenario 1: Deploy Single SNO on AWS

**Documents to read:**
1. [AWS Quick Start](QUICKSTART-AWS.md)

**Commands:**
```bash
./ansible-runner.sh deployaws --limit sno-aws-01
./ansible-runner.sh operators --limit sno-aws-01
./ansible-runner.sh deployapp
```

---

### Scenario 2: Hybrid DR (OpenShift Virt + AWS)

**Documents to read:**
1. [Platform Comparison - Hybrid Approach](PLATFORM-COMPARISON.md#hybrid-approach-recommended-for-dr)
2. [README.md - Complete Deployment Examples](../README.md#complete-deployment-examples)

**Commands:**
```bash
./ansible-runner.sh deploy --limit sno-cluster-01
./ansible-runner.sh deployaws --limit sno-aws-01
./ansible-runner.sh operators
./ansible-runner.sh deployapp
```

---

### Scenario 3: Cost Optimization

**Documents to read:**
1. [AWS Deployment Guide - Cost Optimization](AWS-DEPLOYMENT-GUIDE.md#cost-optimization)
2. [Platform Comparison - Cost Comparison](PLATFORM-COMPARISON.md#cost-comparison)

**Key Actions:**
- Use smaller instance types for dev/test
- Stop instances during off-hours
- Use Reserved Instances for long-term
- Clean up unused resources

---

### Scenario 4: Troubleshooting AWS Deployment

**Documents to read:**
1. [AWS Deployment Guide - Troubleshooting](AWS-DEPLOYMENT-GUIDE.md#troubleshooting)
2. [README.md - Troubleshooting](../README.md#troubleshooting)

**Common Checks:**
- Verify AWS credentials
- Check EC2 instance status
- Validate security group rules
- Verify Route53 DNS records
- Check console output

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
- Platform Comparison: 2024
- AWS Quick Start: 2024
- AWS Deployment Guide: 2024
- AWS Feature Summary: 2024

### Version Compatibility
- OpenShift: 4.14+ (tested with 4.20.2)
- AWS: All regions
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
