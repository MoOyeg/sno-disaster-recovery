# VolSync ReplicationDestination

This directory contains VolSync ReplicationDestination manifests for disaster recovery.

## Overview

The ReplicationDestination is deployed on **standby SNO clusters** to receive data replication from the active cluster. This enables disaster recovery scenarios where data can be failed over to a standby cluster.

## Configuration

### ReplicationDestination

- **Name**: `mysql-replicationdestination`
- **Namespace**: `quarkus-mysql-app`
- **Service Type**: LoadBalancer (allows remote access from active cluster)
- **Replication Method**: rsyncTLS
- **Copy Method**: Snapshot
- **Capacity**: 10Gi
- **Schedule**: Every 5 minutes (`*/5 * * * *`)

### Storage

- **Storage Class**: `ocs-storagecluster-ceph-rbd`
- **Volume Snapshot Class**: `ocs-storagecluster-rbdplugin-snapclass`
- **Access Modes**: ReadWriteOnce

## Deployment

The ReplicationDestination is automatically deployed via ACM and ArgoCD when running:

```bash
./ansible-runner.sh deployapp
```

This creates an ApplicationSet that targets only **standby clusters** (clusters with label `app-role: standby`).

## How It Works

1. The active cluster runs the MySQL database with a ReplicationSource
2. Standby clusters run the ReplicationDestination with LoadBalancer service
3. Data is replicated from active to standby clusters every 5 minutes
4. In a disaster recovery scenario, the standby cluster can be promoted to active

## Monitoring

Check ReplicationDestination status on standby clusters:

```bash
oc get replicationdestination -n quarkus-mysql-app
oc describe replicationdestination mysql-replicationdestination -n quarkus-mysql-app
```

Check the LoadBalancer service:

```bash
oc get svc -n quarkus-mysql-app | grep volsync
```

## Prerequisites

- VolSync operator must be installed on all SNO clusters
- OpenShift Data Foundation (ODF) with RBD storage class
- Volume snapshot support enabled

## Customization

To modify the ReplicationDestination configuration:

1. Edit `replicationdestination.yaml`
2. Commit changes to git
3. ArgoCD will automatically sync the changes to standby clusters

### Common Customizations

- **Replication Frequency**: Modify `spec.trigger.schedule`
- **Capacity**: Adjust `spec.rsyncTLS.capacity`
- **Storage Class**: Change `spec.rsyncTLS.storageClassName`
- **Service Type**: Modify `spec.rsyncTLS.serviceType` (LoadBalancer, ClusterIP, NodePort)
