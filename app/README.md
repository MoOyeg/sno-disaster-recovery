# Quarkus MySQL Application

A simple task management web application built with Quarkus and MySQL for OpenShift.

## Features

- RESTful API for task management (CRUD operations)
- MySQL database integration using Hibernate ORM with Panache
- Health checks (liveness and readiness probes)
- OpenShift-ready deployment manifests

## API Endpoints

- `GET /tasks` - Get all tasks
- `GET /tasks/{id}` - Get a specific task
- `POST /tasks` - Create a new task
- `PUT /tasks/{id}` - Update a task
- `DELETE /tasks/{id}` - Delete a task
- `GET /tasks/completed` - Get completed tasks
- `GET /tasks/pending` - Get pending tasks

## Example Task JSON

```json
{
  "title": "Complete project documentation",
  "description": "Write comprehensive README and API docs",
  "completed": false
}
```

## Local Development

### Prerequisites

- JDK 17+
- Maven 3.8+
- MySQL 8.0+ (or use container)

### Running MySQL locally

```bash
podman run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=quarkusdb \
  -e MYSQL_USER=quarkus \
  -e MYSQL_PASSWORD=quarkus \
  -p 3306:3306 \
  mysql:8.0
```

### Running the application in dev mode

```bash
mvn quarkus:dev
```

The application will be available at http://localhost:8080

### Building the application

```bash
mvn clean package
```

## Deploying to OpenShift

### Prerequisites

- Access to an OpenShift cluster
- `oc` CLI tool configured

### Deploy MySQL

```bash
# Create the namespace
oc apply -f openshift/namespace.yaml

# Deploy MySQL
oc apply -f openshift/mysql-secret.yaml
oc apply -f openshift/mysql-pvc.yaml
oc apply -f openshift/mysql-deployment.yaml
```

### Build and deploy the application

#### Option 1: Build locally and deploy

```bash
# Build the container image
./mvnw package -Pnative -Dquarkus.native.container-build=true

# Tag and push to OpenShift internal registry (if needed)

# Deploy the application
oc apply -f openshift/app-deployment.yaml
```


### Access the application

The application is exposed through two services:

1. **OpenShift Route** (internal cluster access):
```bash
# Get the route URL
oc get route quarkus-mysql-app -o jsonpath='{.spec.host}'
```

2. **MetalLB LoadBalancer** (external access for DR):
```bash
# Get the LoadBalancer IP
oc get service quarkus-mysql-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Access via LoadBalancer
curl http://<loadbalancer-ip>:8080/tasks
```

The LoadBalancer service enables:
- External access from outside the cluster
- Disaster recovery traffic routing
- Direct access for VolSync replication
- Load balancing for production workloads


## Testing the API

### Create a task

```bash
curl -X POST https://<route-url>/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "This is a test task",
    "completed": false
  }'
```

### Get all tasks

```bash
curl https://<route-url>/tasks
```

### Update a task

```bash
curl -X PUT https://<route-url>/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Task",
    "description": "This task has been updated",
    "completed": true
  }'
```

### Delete a task

```bash
curl -X DELETE https://<route-url>/tasks/1
```

## Health Checks

- Liveness: http://localhost:8080/q/health/live
- Readiness: http://localhost:8080/q/health/ready

## Configuration

Database configuration can be overridden using environment variables:

- `DB_HOST` - MySQL host (default: localhost)
- `DB_PORT` - MySQL port (default: 3306)
- `DB_USER` - Database user (default: quarkus)
- `DB_PASSWORD` - Database password (default: quarkus)
- `DB_NAME` - Database name (default: quarkusdb)

## Project Structure

```
app/
├── pom.xml
├── src/
│   └── main/
│       ├── java/com/example/
│       │   ├── entity/
│       │   │   └── Task.java
│       │   └── resource/
│       │       └── TaskResource.java
│       └── resources/
│           └── application.properties
└── openshift/
    ├── mysql-secret.yaml
    ├── mysql-pvc.yaml
    ├── mysql-deployment.yaml
    └── app-deployment.yaml
```
