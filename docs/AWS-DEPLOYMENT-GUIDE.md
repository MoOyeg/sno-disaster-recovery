# AWS Deployment Guide for Single Node OpenShift

This guide provides detailed information for deploying Single Node OpenShift (SNO) clusters on AWS EC2.

## Table of Contents

- [Prerequisites](#prerequisites)
- [AWS Resource Preparation](#aws-resource-preparation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)

## Prerequisites

### AWS Account Setup

1. **AWS Account** with appropriate IAM permissions
2. **AWS CLI** installed and configured:
   ```bash
   # Install AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Configure credentials
   aws configure
   ```

3. **Required IAM Permissions**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:RunInstances",
           "ec2:TerminateInstances",
           "ec2:DescribeInstances",
           "ec2:CreateVolume",
           "ec2:AttachVolume",
           "ec2:DescribeVolumes",
           "ec2:CreateTags",
           "ec2:AllocateAddress",
           "ec2:AssociateAddress",
           "ec2:DescribeAddresses",
           "ec2:DescribeImages",
           "ec2:DescribeSecurityGroups",
           "ec2:DescribeSubnets",
           "ec2:DescribeVpcs",
           "route53:ChangeResourceRecordSets",
           "route53:ListHostedZones",
           "route53:GetChange",
           "s3:PutObject",
           "s3:GetObject",
           "s3:ListBucket"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

## AWS Resource Preparation

### 1. VPC and Networking

#### Option A: Use Existing VPC

```bash
# List available VPCs
aws ec2 describe-vpcs --region us-east-1

# List subnets in VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
  --region us-east-1 \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]'
```

#### Option B: Create New VPC

```bash
# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region us-east-1 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=sno-vpc}]' \
  --query 'Vpc.VpcId' --output text)

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --region us-east-1 \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=sno-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region us-east-1

# Create Public Subnet
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --region us-east-1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sno-public-subnet}]' \
  --query 'Subnet.SubnetId' --output text)

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch \
  --region us-east-1

# Create Route Table
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region us-east-1 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=sno-public-rtb}]' \
  --query 'RouteTable.RouteTableId' --output text)

# Add Internet Gateway route
aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region us-east-1

# Associate route table with subnet
aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $RTB_ID \
  --region us-east-1

echo "VPC_ID: $VPC_ID"
echo "SUBNET_ID: $SUBNET_ID"
```

### 2. Security Group

Create a security group with required ports:

```bash
# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name sno-security-group \
  --description "Security group for SNO cluster" \
  --vpc-id $VPC_ID \
  --region us-east-1 \
  --output text --query 'GroupId')

# Allow SSH (from your IP)
MY_IP=$(curl -s https://ifconfig.me)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 \
  --cidr ${MY_IP}/32 \
  --region us-east-1

# Allow OpenShift API (6443)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 6443 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

# Allow HTTP (80)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

# Allow HTTPS (443)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 443 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

# Allow Machine Config Server (22623)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22623 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

# Allow all outbound traffic (default)
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --protocol -1 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

echo "SECURITY_GROUP_ID: $SG_ID"
```

### 3. EC2 Key Pair

```bash
# Create new key pair
aws ec2 create-key-pair \
  --key-name sno-keypair \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/sno-keypair.pem

chmod 400 ~/.ssh/sno-keypair.pem

# Or import existing public key
aws ec2 import-key-pair \
  --key-name sno-keypair \
  --public-key-material fileb://~/.ssh/id_rsa.pub \
  --region us-east-1
```

### 4. Find RHCOS AMI

#### Method 1: AWS EC2 Console

1. Go to EC2 Console → Images → AMIs
2. Change filter to "Public images"
3. Search for: "Red Hat CoreOS"
4. Filter by OpenShift version (e.g., "4.20")
5. Copy AMI ID

#### Method 2: AWS CLI

```bash
# Search for RHCOS AMI
aws ec2 describe-images \
  --region us-east-1 \
  --owners 309956199498 \
  --filters "Name=name,Values=RHCOS-4.20*" \
  --query 'Images[*].[ImageId,Name,CreationDate]' \
  --output table

# Get latest RHCOS AMI for specific version
AMI_ID=$(aws ec2 describe-images \
  --region us-east-1 \
  --owners 309956199498 \
  --filters "Name=name,Values=RHCOS-4.20*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "Latest RHCOS AMI: $AMI_ID"
```

#### Method 3: Red Hat Mirror

Visit: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/

Navigate to your OpenShift version and find `rhcos-aws.json`

### 5. Route53 Hosted Zone (Optional)

```bash
# List existing hosted zones
aws route53 list-hosted-zones \
  --query 'HostedZones[*].[Name,Id]' \
  --output table

# Create new hosted zone
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s) \
  --hosted-zone-config Comment="SNO clusters zone"
```

## Configuration

### 1. Create Host Variables File

Copy the example configuration:

```bash
cp inventory/host_vars/sno-aws-example.yml inventory/host_vars/sno-aws-01.yml
```

### 2. Edit Configuration

Edit `inventory/host_vars/sno-aws-01.yml`:

```yaml
---
# Cluster identification
sno_cluster_name: "sno-aws-01"
sno_base_domain: "example.com"

# AWS Configuration
aws_region: "us-east-1"
aws_availability_zone: "us-east-1a"
aws_instance_type: "m5.2xlarge"
aws_root_volume_size: 120
aws_secondary_volume_size: 100

# RHCOS AMI (update with your AMI ID)
aws_ami_id: "ami-0123456789abcdef0"

# Network Configuration (update with your values)
aws_vpc_id: "vpc-xxxxxxxxxxxxxxxxx"
aws_subnet_id: "subnet-xxxxxxxxxxxxxxxxx"
aws_security_group_id: "sg-xxxxxxxxxxxxxxxxx"

# SSH Key
aws_key_name: "sno-keypair"

# Optional: Elastic IP
aws_create_eip: true

# Optional: Route53 DNS
aws_route53_zone: "example.com"

# Storage device (AWS uses NVMe naming)
sno_secondary_disk_device: "/dev/nvme1n1"

# OpenShift version
sno_openshift_version: "4.20.2"

# ACM labels
acm_labels:
  cluster-type: sno
  environment: aws
  region: "{{ aws_region }}"
```

### 3. Add to Inventory

Edit `inventory/hosts` and add:

```ini
[sno_clusters]
sno-aws-01 ansible_connection=local
```

## Deployment

### 1. Set Up Authentication

```bash
# Hub cluster (for ACM integration)
export KUBECONFIG=~/.kube/config

# AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
# OR
export AWS_PROFILE="your-profile-name"

# Ensure pull secret exists
ls -l pull-secret.json
ls -l ssh-key.pub
```

### 2. Deploy Cluster

```bash
# Deploy SNO cluster on AWS
./ansible-runner.sh deployaws --limit sno-aws-01
```

### 3. Monitor Progress

In another terminal, monitor AWS resources:

```bash
# Watch EC2 instance creation
watch -n 10 'aws ec2 describe-instances \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" \
  --output table'

# View console output (after instance is running)
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

aws ec2 get-console-output --instance-id $INSTANCE_ID --region us-east-1
```

## Verification

### 1. Check Cluster Credentials

```bash
# Credentials are saved in artifacts directory
ls -la artifacts/sno-aws-01/
cat artifacts/sno-aws-01/cluster-info.txt
```

### 2. Access Cluster

```bash
# Use kubeconfig
export KUBECONFIG=artifacts/sno-aws-01/kubeconfig

# Verify cluster
oc get nodes
oc get co

# Check cluster version
oc get clusterversion
```

### 3. Access Console

If Route53 is configured:
```
https://console-openshift-console.apps.sno-aws-01.example.com
```

If not, use Elastic IP:
```
https://<elastic-ip>:8443
```

Username: `kubeadmin`
Password: `cat artifacts/sno-aws-01/kubeadmin-password`

### 4. SSH to Instance

```bash
# Get Elastic IP
EIP=$(aws ec2 describe-addresses \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query 'Addresses[0].PublicIp' \
  --output text)

# SSH to instance
ssh -i ~/.ssh/sno-keypair.pem core@$EIP

# Once inside, check OpenShift services
sudo crictl ps
sudo journalctl -u kubelet
```

## Troubleshooting

### Instance Launch Issues

```bash
# Check EC2 instance limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-1

# Check available capacity
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=m5.2xlarge \
  --region us-east-1
```

### DNS Issues

```bash
# Verify Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(aws route53 list-hosted-zones-by-name \
    --dns-name example.com \
    --query 'HostedZones[0].Id' \
    --output text) \
  | grep -A 2 "sno-aws-01"

# Test DNS resolution
nslookup api.sno-aws-01.example.com
nslookup test.apps.sno-aws-01.example.com
```

### Network Connectivity

```bash
# Test API endpoint
curl -k https://api.sno-aws-01.example.com:6443/healthz

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region us-east-1 \
  --query 'SecurityGroups[*].IpPermissions[*]'
```

### Storage Issues

```bash
# List EBS volumes
aws ec2 describe-volumes \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query 'Volumes[*].[VolumeId,Size,State,Attachments[0].Device]'

# Check NVMe devices (SSH to instance)
ssh -i ~/.ssh/sno-keypair.pem core@$EIP
lsblk
sudo nvme list
```

## Cost Optimization

### 1. Instance Sizing

- **Development/Testing**: m5.2xlarge ($0.384/hour)
- **Production**: m5.4xlarge ($0.768/hour)
- **High Performance**: m5.8xlarge ($1.536/hour)

### 2. EBS Volume Optimization

```yaml
# Use gp3 instead of gp2 (included in playbook)
aws_root_volume_size: 120      # Minimum for OpenShift
aws_secondary_volume_size: 50   # Reduce if not using Local Storage
```

### 3. Elastic IP

- Elastic IPs are free when associated with running instances
- Charged $0.005/hour when not associated
- Set `aws_create_eip: false` if using temporary deployments

### 4. Data Transfer

- Ingress: Free
- Egress: First 100GB/month free, then $0.09/GB
- Inter-AZ: $0.01/GB each direction

### 5. Cost Estimation

Monthly cost for typical SNO deployment:

```
Instance (m5.2xlarge):     $280/month (24x7)
EBS (220GB gp3):           $18/month
Elastic IP:                $0 (when associated)
Data transfer (100GB):     $0 (within free tier)
Route53 (hosted zone):     $0.50/month
Route53 (queries):         $0.40/million queries
                          ─────────────
Total:                     ~$300/month
```

### 6. Cost-Saving Tips

- Use AWS Savings Plans or Reserved Instances for long-term deployments
- Stop instances during off-hours (requires cluster recovery)
- Use Spot Instances for non-production (not recommended for SNO)
- Delete unused Elastic IPs
- Clean up old EBS snapshots
- Use S3 lifecycle policies for ISO storage

## Cleanup

### Manual Cleanup

```bash
# Terminate EC2 instance
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-east-1

# Wait for termination
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region us-east-1

# Delete EBS volumes (if not auto-deleted)
aws ec2 describe-volumes \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query 'Volumes[*].VolumeId' \
  --output text | xargs -I {} aws ec2 delete-volume --volume-id {} --region us-east-1

# Release Elastic IP
EIP_ALLOC=$(aws ec2 describe-addresses \
  --filters "Name=tag:cluster,Values=sno-aws-01" \
  --region us-east-1 \
  --query 'Addresses[0].AllocationId' \
  --output text)

aws ec2 release-address --allocation-id $EIP_ALLOC --region us-east-1

# Delete Route53 records (manual via console or CLI)
```

### Automated Cleanup Script

Save this as `cleanup-aws-sno.sh`:

```bash
#!/bin/bash
CLUSTER_NAME=$1
REGION=${2:-us-east-1}

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <cluster-name> [region]"
  exit 1
fi

echo "Cleaning up AWS resources for cluster: $CLUSTER_NAME in region: $REGION"

# Terminate instances
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:cluster,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running,stopped" \
  --region $REGION \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
fi

# Delete volumes
VOLUME_IDS=$(aws ec2 describe-volumes \
  --filters "Name=tag:cluster,Values=$CLUSTER_NAME" \
  --region $REGION \
  --query 'Volumes[*].VolumeId' \
  --output text)

if [ -n "$VOLUME_IDS" ]; then
  echo "Deleting volumes: $VOLUME_IDS"
  for vol in $VOLUME_IDS; do
    aws ec2 delete-volume --volume-id $vol --region $REGION 2>/dev/null || true
  done
fi

# Release Elastic IPs
EIP_ALLOCS=$(aws ec2 describe-addresses \
  --filters "Name=tag:cluster,Values=$CLUSTER_NAME" \
  --region $REGION \
  --query 'Addresses[*].AllocationId' \
  --output text)

if [ -n "$EIP_ALLOCS" ]; then
  echo "Releasing Elastic IPs: $EIP_ALLOCS"
  for eip in $EIP_ALLOCS; do
    aws ec2 release-address --allocation-id $eip --region $REGION
  done
fi

echo "Cleanup complete!"
echo "Note: Route53 records must be deleted manually"
```

Usage:
```bash
chmod +x cleanup-aws-sno.sh
./cleanup-aws-sno.sh sno-aws-01 us-east-1
```

## Additional Resources

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [OpenShift on AWS](https://docs.openshift.com/container-platform/latest/installing/installing_aws/installing-aws-default.html)
- [RHCOS Images](https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Route53 Documentation](https://docs.aws.amazon.com/route53/)
