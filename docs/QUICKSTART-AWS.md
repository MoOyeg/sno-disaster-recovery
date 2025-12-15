# Quick Start Guide - AWS SNO Deployment

This guide gets you from zero to a running Single Node OpenShift cluster on AWS in under an hour.

## Prerequisites Checklist

- [ ] AWS account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] Podman or Docker installed
- [ ] Pull secret from Red Hat
- [ ] SSH key pair
- [ ] OpenShift hub cluster kubeconfig (for ACM integration)

## Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/sno-cluster-ocpv.git
cd sno-cluster-ocpv
```

## Step 2: Prepare AWS Resources

### Quick VPC Setup (10 minutes)

```bash
export AWS_REGION="us-east-1"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=sno-vpc}]' \
  --query 'Vpc.VpcId' --output text)

# Create and attach Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=sno-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $AWS_REGION

# Create Public Subnet
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${AWS_REGION}a \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sno-subnet}]' \
  --query 'Subnet.SubnetId' --output text)

aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION

# Create and configure Route Table
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=sno-rtb}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $AWS_REGION

aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $RTB_ID \
  --region $AWS_REGION

# Create Security Group
SG_ID=$(aws ec2 create-security-group \
  --group-name sno-sg \
  --description "SNO cluster security group" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --output text --query 'GroupId')

# Allow necessary ports
MY_IP=$(curl -s https://ifconfig.me)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --ip-permissions \
    IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges="[{CidrIp=${MY_IP}/32}]" \
    IpProtocol=tcp,FromPort=6443,ToPort=6443,IpRanges="[{CidrIp=0.0.0.0/0}]" \
    IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges="[{CidrIp=0.0.0.0/0}]" \
    IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges="[{CidrIp=0.0.0.0/0}]" \
    IpProtocol=tcp,FromPort=22623,ToPort=22623,IpRanges="[{CidrIp=0.0.0.0/0}]" \
  --region $AWS_REGION

# Create EC2 Key Pair
aws ec2 create-key-pair \
  --key-name sno-keypair \
  --region $AWS_REGION \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/sno-keypair.pem

chmod 400 ~/.ssh/sno-keypair.pem

# Display resource IDs (save these!)
echo "=== AWS Resources Created ==="
echo "VPC_ID: $VPC_ID"
echo "SUBNET_ID: $SUBNET_ID"
echo "SECURITY_GROUP_ID: $SG_ID"
echo "KEY_NAME: sno-keypair"
echo "=============================="
```

### Find RHCOS AMI

```bash
# Get latest RHCOS AMI for OpenShift 4.20
AMI_ID=$(aws ec2 describe-images \
  --region $AWS_REGION \
  --owners 309956199498 \
  --filters "Name=name,Values=RHCOS-4.20*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "RHCOS AMI: $AMI_ID"
```

## Step 3: Configure Cluster

Create `inventory/host_vars/sno-aws-quickstart.yml`:

```bash
cat > inventory/host_vars/sno-aws-quickstart.yml <<EOF
---
# Cluster identification
sno_cluster_name: "sno-aws-quickstart"
sno_base_domain: "example.com"

# AWS Configuration
aws_region: "${AWS_REGION}"
aws_availability_zone: "${AWS_REGION}a"
aws_instance_type: "m5.2xlarge"
aws_root_volume_size: 120
aws_secondary_volume_size: 100

# RHCOS AMI
aws_ami_id: "${AMI_ID}"

# Network Configuration
aws_vpc_id: "${VPC_ID}"
aws_subnet_id: "${SUBNET_ID}"
aws_security_group_id: "${SG_ID}"

# SSH Key
aws_key_name: "sno-keypair"

# Elastic IP
aws_create_eip: true

# Storage device (AWS NVMe)
sno_secondary_disk_device: "/dev/nvme1n1"

# OpenShift version
sno_openshift_version: "4.20.2"

# ACM labels
acm_labels:
  cluster-type: sno
  environment: quickstart
  region: "${AWS_REGION}"
EOF
```

Add to inventory:

```bash
cat >> inventory/hosts <<EOF

sno-aws-quickstart ansible_connection=local
EOF
```

## Step 4: Set Up Authentication

```bash
# Hub cluster (for ACM)
export KUBECONFIG=~/.kube/config

# AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Ensure pull secret exists
cp ~/Downloads/pull-secret.json ./pull-secret.json

# Ensure SSH key exists
cp ~/.ssh/id_rsa.pub ./ssh-key.pub
```

## Step 5: Build Ansible Container

```bash
./setup.sh
```

## Step 6: Deploy Cluster

```bash
./ansible-runner.sh deployaws --limit sno-aws-quickstart
```

This will take approximately 45-60 minutes.

## Step 7: Monitor Progress

In another terminal:

```bash
# Watch EC2 instance
watch -n 10 'aws ec2 describe-instances \
  --filters "Name=tag:cluster,Values=sno-aws-quickstart" \
  --region ${AWS_REGION} \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" \
  --output table'
```

## Step 8: Access Cluster

After deployment completes:

```bash
# Export kubeconfig
export KUBECONFIG=artifacts/sno-aws-quickstart/kubeconfig

# Verify cluster
oc get nodes
oc get co

# Get console URL and password
cat artifacts/sno-aws-quickstart/cluster-info.txt
cat artifacts/sno-aws-quickstart/kubeadmin-password
```

## Step 9: Deploy Infrastructure Operators

```bash
# Deploy operators via ACM
./ansible-runner.sh operators --limit sno-aws-quickstart
```

Wait 10-15 minutes for operators to install.

## Step 10: Deploy Sample Application

```bash
# Deploy Quarkus MySQL app via GitOps
./ansible-runner.sh deployapp
```

## Verification

```bash
# Check operators
export KUBECONFIG=artifacts/sno-aws-quickstart/kubeconfig

oc get csv -n openshift-operators
oc get pods -n metallb-system
oc get pods -n openshift-gitops

# Check application
oc get pods -n quarkus-mysql-app
oc get route -n quarkus-mysql-app
```

## Access Application

Get the application URL:

```bash
oc get route quarkus-mysql-app -n quarkus-mysql-app -o jsonpath='{.spec.host}'
```

Open in browser: `https://<route-host>`

## Cleanup

When done:

```bash
# Terminate EC2 instance
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:cluster,Values=sno-aws-quickstart" \
  --region ${AWS_REGION} \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region ${AWS_REGION}

# Clean up other resources (see AWS-DEPLOYMENT-GUIDE.md)
```

## Troubleshooting

### Issue: EC2 instance not launching

**Solution**: Check instance limits
```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region ${AWS_REGION}
```

### Issue: Can't reach API endpoint

**Solution**: Check security group rules
```bash
aws ec2 describe-security-groups \
  --group-ids ${SG_ID} \
  --region ${AWS_REGION}
```

### Issue: Installation timeout

**Solution**: Check console output
```bash
aws ec2 get-console-output \
  --instance-id $INSTANCE_ID \
  --region ${AWS_REGION}
```

### Issue: SSH connection refused

**Solution**: Wait for cloud-init to complete (5-10 minutes after instance starts)
```bash
# Check instance status
aws ec2 describe-instance-status \
  --instance-ids $INSTANCE_ID \
  --region ${AWS_REGION}
```

## Next Steps

1. **Set up Route53 DNS**: Add `aws_route53_zone` to configuration for automatic DNS
2. **Deploy second cluster**: Create another SNO on OpenShift Virtualization for DR testing
3. **Configure Submariner**: Automatic if MetalLB subnets differ
4. **Test application DR**: Verify app runs on both clusters
5. **Explore GitOps**: Modify application in Git and watch automatic deployment

## Cost Estimate

Running 24/7:
- **m5.2xlarge**: ~$280/month
- **EBS volumes**: ~$18/month
- **Elastic IP**: $0 (when associated)
- **Total**: ~$300/month

**Tip**: Stop instances when not in use to save costs (requires cluster recovery).

## Support

- **Documentation**: See `README.md` and `docs/AWS-DEPLOYMENT-GUIDE.md`
- **Issues**: Check troubleshooting section in AWS deployment guide
- **Logs**: Check `artifacts/sno-aws-quickstart/` directory

## Summary

You now have:
✅ Single Node OpenShift cluster running on AWS EC2  
✅ Infrastructure operators (MetalLB, LVM, GitOps) installed  
✅ Sample Quarkus MySQL application deployed  
✅ Ready for DR configuration with second cluster  

**Total time**: ~1 hour  
**Monthly cost**: ~$300
