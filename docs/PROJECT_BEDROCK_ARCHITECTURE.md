# Project Bedrock Architecture

## Overview

Project Bedrock provisions a production-grade Kubernetes environment on AWS EKS to host the Retail Store Sample Application. The architecture follows AWS best practices for security, scalability, and observability.

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                          │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    VPC: project-bedrock-vpc                         │   │
│  │                         CIDR: 10.0.0.0/16                           │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │              Public Subnets (2 AZs)                         │   │   │
│  │  │  - 10.0.101.0/24 (us-east-1a)                              │   │   │
│  │  │  - 10.0.102.0/24 (us-east-1b)                              │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────┐    ┌─────────────────┐                │   │   │
│  │  │  │  Internet       │    │  NAT Gateway    │                │   │   │
│  │  │  │  Gateway        │    │                 │                │   │   │
│  │  │  └─────────────────┘    └─────────────────┘                │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │              Private Subnets (2 AZs)                        │   │   │
│  │  │  - 10.0.1.0/24 (us-east-1a)                                │   │   │
│  │  │  - 10.0.2.0/24 (us-east-1b)                                │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │              EKS Cluster                            │   │   │   │
│  │  │  │         project-bedrock-cluster                     │   │   │   │
│  │  │  │              (v1.34+)                               │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  ┌─────────────────────────────────────────────┐   │   │   │   │
│  │  │  │  │           retail-app Namespace              │   │   │   │   │
│  │  │  │  │                                             │   │   │   │   │
│  │  │  │  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │   │   │   │   │
│  │  │  │  │  │ UI  │ │Cart │ │Cat  │ │Ord  │ │Chk  │  │   │   │   │   │
│  │  │  │  │  │     │ │     │ │     │ │     │ │     │  │   │   │   │   │
│  │  │  │  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  │   │   │   │   │
│  │  │  │  │                                             │   │   │   │   │
│  │  │  │  │  ┌─────────┐ ┌─────────┐                   │   │   │   │   │
│  │  │  │  │  │ RabbitMQ│ │  Redis  │                   │   │   │   │   │
│  │  │  │  │  └─────────┘ └─────────┘                   │   │   │   │   │
│  │  │  │  └─────────────────────────────────────────────┘   │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  ┌─────────────────────────────────────────────┐   │   │   │   │
│  │  │  │  │         AWS Load Balancer Controller        │   │   │   │   │
│  │  │  │  └─────────────────────────────────────────────┘   │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────┐ ┌─────────────────┐                   │   │   │
│  │  │  │  RDS MySQL      │ │  RDS PostgreSQL │  (Private)        │   │   │
│  │  │  │  (Catalog)      │ │  (Orders)       │                   │   │   │
│  │  │  └─────────────────┘ └─────────────────┘                   │   │   │
│  │  │                                                             │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  ┌─────────────────┐ ┌─────────────────┐                           │   │
│  │  │  S3 Bucket      │ │  DynamoDB       │                           │   │
│  │  │  bedrock-assets-│ │  retail-carts   │                           │   │
│  │  │  3765           │ │                 │                           │   │
│  │  └─────────────────┘ └─────────────────┘                           │   │
│  │           │                                                         │   │
│  │           │ s3:ObjectCreated:*                                      │   │
│  │           ▼                                                         │   │
│  │  ┌─────────────────┐                                               │   │
│  │  │  Lambda         │                                               │   │
│  │  │  bedrock-asset  │                                               │   │
│  │  │  -processor     │                                               │   │
│  │  └─────────────────┘                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────┐                                                       │
│  │  Secrets        │                                                       │
│  │  Manager        │                                                       │
│  │  - catalog-db   │                                                       │
│  │  - orders-db    │                                                       │
│  └─────────────────┘                                                       │
│                                                                             │
│  ┌─────────────────┐                                                       │
│  │  CloudWatch     │◄──────────────────────────────────────────────────┐   │
│  │  - Logs         │                                                    │   │
│  │  - Metrics      │  EKS Control Plane Logs:                           │   │
│  │  - Alarms       │  - API Server                                      │   │
│  └─────────────────┘  - Audit                                           │   │
│                       - Authenticator                                   │   │
│                       - Controller Manager                              │   │
│                       - Scheduler                                       │   │
│                                                                         │   │
│  ┌─────────────────┐                                                    │   │
│  │  IAM            │                                                    │   │
│  │  - bedrock-dev  │                                                    │   │
│  │  -view          │                                                    │   │
│  │  - EKS Cluster  │                                                    │   │
│  │  - IRSA Roles   │                                                    │   │
│  └─────────────────┘                                                    │   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Networking (VPC)
- **Name:** project-bedrock-vpc
- **CIDR:** 10.0.0.0/16
- **Availability Zones:** us-east-1a, us-east-1b
- **Public Subnets:** 2 subnets for ALB and NAT Gateway
- **Private Subnets:** 2 subnets for EKS nodes, RDS instances
- **NAT Gateway:** For private subnet internet access

### 2. EKS Cluster
- **Name:** project-bedrock-cluster
- **Version:** 1.34+
- **Control Plane Logging:** API, Audit, Authenticator, ControllerManager, Scheduler
- **Add-ons:** CoreDNS, kube-proxy, vpc-cni, amazon-cloudwatch-observability
- **Node Groups:** Managed node group with t3.medium instances

### 3. Data Layer
- **RDS MySQL:** For Catalog service (private subnets)
- **RDS PostgreSQL:** For Orders service (private subnets)
- **DynamoDB:** For Carts service (serverless, PAY_PER_REQUEST)
- **Secrets Manager:** Stores database credentials securely

### 4. Application Services (retail-app namespace)
- **UI:** Store frontend (Java)
- **Catalog:** Product catalog API (Go)
- **Cart:** Shopping cart API (Java)
- **Orders:** Orders API (Java)
- **Checkout:** Checkout orchestration (Node.js)
- **RabbitMQ:** Message broker for orders
- **Redis:** Cache for checkout

### 5. Serverless Extension
- **S3 Bucket:** bedrock-assets-3765 (private, versioned)
- **Lambda:** bedrock-asset-processor (Python 3.12)
- **Trigger:** S3 ObjectCreated events invoke Lambda

### 6. Security
- **IAM User:** bedrock-dev-view with ReadOnlyAccess
- **EKS Access:** IAM role mapping to Kubernetes view ClusterRole
- **IRSA:** IAM Roles for Service Accounts for DynamoDB access
- **Resource Tagging:** All resources tagged with Project=karatu-2025-capstone

### 7. Ingress
- **AWS Load Balancer Controller:** Manages ALB lifecycle
- **ALB:** Internet-facing, targets pods directly (IP mode)
- **TLS:** Optional HTTPS with ACM certificate

## Data Flow

1. **User Request → UI → Services → Data Layer**
   - User accesses ALB endpoint
   - ALB routes to UI service in EKS
   - UI communicates with backend services
   - Services persist data to RDS/DynamoDB

2. **Asset Upload → S3 → Lambda**
   - Assets uploaded to S3 bucket
   - S3 event triggers Lambda function
   - Lambda logs filename to CloudWatch

3. **Observability**
   - EKS control plane logs → CloudWatch Logs
   - Application logs → CloudWatch Logs (via CloudWatch Observability add-on)
   - Metrics → CloudWatch Metrics

## CI/CD Pipeline

- **Pull Request:** Triggers `terraform plan`, posts comment
- **Merge to Main:** Triggers `terraform apply`
- **Authentication:** GitHub OIDC → AWS IAM Role

## Resource Tagging

All AWS resources are tagged with:
- `Project: karatu-2025-capstone`

This enables cost allocation and resource identification for grading.