#!/usr/bin/env bash
set -euo pipefail

# Cleanup script for Project Bedrock
# Deletes Kubernetes resources and destroys all Terraform-managed AWS infrastructure

echo "Starting cleanup of all resources..."

AWS_REGION="${AWS_REGION:-us-east-1}"
TFSTATE_BUCKET="${TFSTATE_BUCKET:-project-bedrock-tfstate-3765}"
ASSETS_BUCKET="${ASSETS_BUCKET:-bedrock-assets-3765}"
CLUSTER_NAME="${CLUSTER_NAME:-project-bedrock-cluster}"
IAM_USER="${IAM_USER:-bedrock-dev-view}"
LAMBDA_NAME="${LAMBDA_NAME:-bedrock-asset-processor}"
NAME_PREFIX="${NAME_PREFIX:-project-bedrock}"
DDB_TABLE="${DDB_TABLE:-retail-carts}"
PROJECT_TAG="${PROJECT_TAG:-karatu-2025-capstone}"
VPC_NAME="${VPC_NAME:-project-bedrock-vpc}"
LEFTOVER_ENI_ID="${LEFTOVER_ENI_ID:-}"

delete_bucket_if_exists() {
	local bucket="$1"
	if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
		echo "Deleting S3 bucket $bucket and all its contents..."
		aws s3 rm "s3://$bucket" --recursive || true

		# Remove versioned objects/delete markers when bucket versioning is enabled.
		aws s3api list-object-versions --bucket "$bucket" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null | while read -r key version_id; do
			[[ -n "${key:-}" && -n "${version_id:-}" ]] || continue
			aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version_id" >/dev/null 2>&1 || true
		done
		aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null | while read -r key version_id; do
			[[ -n "${key:-}" && -n "${version_id:-}" ]] || continue
			aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version_id" >/dev/null 2>&1 || true
		done

		aws s3api delete-bucket --bucket "$bucket" || true
	else
		echo "S3 bucket $bucket does not exist or is already deleted."
	fi
}

# Helper function to detach all policies from a role and delete it
delete_iam_role() {
	local role_name="$1"
	
	# Check if role exists
	if ! aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
		echo "IAM role $role_name does not exist."
		return 0
	fi
	
	echo "Deleting IAM role: $role_name"
	
	# Detach all attached policies
	local attached_policies
	attached_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true)
	for policy_arn in $attached_policies; do
		[[ -n "$policy_arn" ]] || continue
		aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" >/dev/null 2>&1 || true
	done
	
	# Delete all inline policies
	local inline_policies
	inline_policies=$(aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames[]' --output text 2>/dev/null || true)
	for policy_name in $inline_policies; do
		[[ -n "$policy_name" ]] || continue
		aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy_name" >/dev/null 2>&1 || true
	done
	
	# Delete the role
	aws iam delete-role --role-name "$role_name" >/dev/null 2>&1 || true
}

# Helper function to delete an IAM policy
delete_iam_policy() {
	local policy_name="$1"
	
	# Find the policy ARN
	local policy_arn
	policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$policy_name'].Arn | [0]" --output text 2>/dev/null || true)
	
	if [[ -z "$policy_arn" || "$policy_arn" == "None" ]]; then
		echo "IAM policy $policy_name does not exist."
		return 0
	fi
	
	echo "Deleting IAM policy: $policy_name ($policy_arn)"
	
	# First, detach from any roles
	local attached_roles
	attached_roles=$(aws iam list-entities-for-policy --policy-arn "$policy_arn" --query 'Roles[].RoleName' --output text 2>/dev/null || true)
	for role_name in $attached_roles; do
		[[ -n "$role_name" ]] || continue
		aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" >/dev/null 2>&1 || true
	done
	
	# Delete the policy
	aws iam delete-policy --policy-arn "$policy_arn" >/dev/null 2>&1 || true
}

# Helper function to delete CloudWatch log group
delete_log_group() {
	local log_group_name="$1"
	if aws logs describe-log-groups --log-group-name-prefix "$log_group_name" --region "$AWS_REGION" --query "logGroups[?logGroupName=='$log_group_name']" --output text >/dev/null 2>&1; then
		echo "Deleting CloudWatch log group: $log_group_name"
		aws logs delete-log-group --log-group-name "$log_group_name" --region "$AWS_REGION" >/dev/null 2>&1 || true
	fi
}

manual_fallback_cleanup() {
	echo "Running fallback AWS cleanup for known Bedrock resources..."

	# EKS resources
	echo "Cleaning up EKS cluster and related resources..."
	
	# Delete EKS access policy associations first
	for association in $(aws eks list-access-policies --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'associatedAccessPolicies[].association.associationArn' --output text 2>/dev/null); do
		[[ -n "$association" ]] || continue
		echo "Deleting EKS access policy association: $association"
		aws eks delete-access-policy --cluster-name "$CLUSTER_NAME" --association-arn "$association" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete EKS access entries
	for entry in $(aws eks list-access-entries --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'accessEntries[].principalArn' --output text 2>/dev/null); do
		[[ -n "$entry" ]] || continue
		echo "Deleting EKS access entry: $entry"
		aws eks delete-access-entry --cluster-name "$CLUSTER_NAME" --principal-arn "$entry" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete EKS addons
	for addon in $(aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'addons[]' --output text 2>/dev/null); do
		[[ -n "$addon" ]] || continue
		echo "Deleting EKS addon: $addon"
		aws eks delete-addon --cluster-name "$CLUSTER_NAME" --addon-name "$addon" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete EKS nodegroups
	for ng in $(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups[]' --output text 2>/dev/null); do
		[[ -n "$ng" ]] || continue
		echo "Deleting EKS node group: $ng"
		aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete EKS cluster
	aws eks delete-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || true

	# Data layer cleanup
	echo "Cleaning up data layer resources..."
	
	# Delete RDS instances
	aws rds delete-db-instance --db-instance-identifier "${NAME_PREFIX}-catalog-mysql" --skip-final-snapshot --delete-automated-backups --region "$AWS_REGION" >/dev/null 2>&1 || true
	aws rds delete-db-instance --db-instance-identifier "${NAME_PREFIX}-orders-postgres" --skip-final-snapshot --delete-automated-backups --region "$AWS_REGION" >/dev/null 2>&1 || true
	
	# Delete DynamoDB table
	aws dynamodb delete-table --table-name "$DDB_TABLE" --region "$AWS_REGION" >/dev/null 2>&1 || true

	# Delete Secrets Manager secrets
	aws secretsmanager delete-secret --secret-id "${NAME_PREFIX}/catalog-db" --force-delete-without-recovery --region "$AWS_REGION" >/dev/null 2>&1 || true
	aws secretsmanager delete-secret --secret-id "${NAME_PREFIX}/orders-db" --force-delete-without-recovery --region "$AWS_REGION" >/dev/null 2>&1 || true

	# Lambda and assets cleanup
	echo "Cleaning up Lambda and S3 resources..."
	
	# Delete Lambda permissions first
	aws lambda remove-permission --function-name "$LAMBDA_NAME" --statement-id "AllowExecutionFromS3Bucket" --region "$AWS_REGION" >/dev/null 2>&1 || true
	aws lambda delete-function --function-name "$LAMBDA_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || true
	
	# Delete S3 bucket notifications (to prevent Lambda trigger issues)
	aws s3api put-bucket-notification-configuration --bucket "$ASSETS_BUCKET" --notification-configuration file:///dev/null --region "$AWS_REGION" 2>/dev/null || true
	
	delete_bucket_if_exists "$ASSETS_BUCKET"

	# IAM user cleanup (developer user)
	echo "Cleaning up IAM user: $IAM_USER"
	
	for key_id in $(aws iam list-access-keys --user-name "$IAM_USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
		[[ -n "$key_id" ]] || continue
		aws iam delete-access-key --user-name "$IAM_USER" --access-key-id "$key_id" >/dev/null 2>&1 || true
	done
	aws iam delete-login-profile --user-name "$IAM_USER" >/dev/null 2>&1 || true
	aws iam detach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess >/dev/null 2>&1 || true
	aws iam delete-user-policy --user-name "$IAM_USER" --policy-name "${IAM_USER}-s3-put-object" >/dev/null 2>&1 || true
	aws iam delete-user --user-name "$IAM_USER" >/dev/null 2>&1 || true

	# IAM roles cleanup
	echo "Cleaning up IAM roles..."
	delete_iam_role "${NAME_PREFIX}-carts-irsa"
	delete_iam_role "lambda_exec_role"
	delete_iam_role "${NAME_PREFIX}-adot-col-xray"
	delete_iam_role "${NAME_PREFIX}-adot-col-logs"

	# IAM policies cleanup
	echo "Cleaning up IAM policies..."
	delete_iam_policy "${NAME_PREFIX}-carts-dynamodb"

	# GitHub Actions OIDC provider cleanup
	echo "Cleaning up GitHub Actions OIDC provider..."
	OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text 2>/dev/null || true)
	if [[ -n "${OIDC_ARN:-}" && "${OIDC_ARN:-}" != "None" ]]; then
		aws iam delete-open-id-connect-provider --open-id-provider-arn "$OIDC_ARN" >/dev/null 2>&1 || true
	fi

	# IAM roles for GitHub Actions
	delete_iam_role "${NAME_PREFIX}-github-actions-terraform"

	# Clean up additional resources that may be left behind
	echo "Cleaning up additional resources..."
	
	# Delete CloudWatch log groups
	delete_log_group "/aws/eks/${CLUSTER_NAME}"
	delete_log_group "${NAME_PREFIX}-tasks"
	delete_log_group "/aws/events/ecs/containerinsights/${NAME_PREFIX}-cluster/performance"
	
	# Delete ECS cluster (if ECS deployment was used)
	aws ecs delete-cluster --cluster "${NAME_PREFIX}-cluster" --region "$AWS_REGION" >/dev/null 2>&1 || true
	
	# Delete Service Discovery namespace
	ns_id=$(aws servicediscovery list-namespaces --query "Namespaces[?Name=='retailstore.local'].Id | [0]" --output text 2>/dev/null || true)
	if [[ -n "${ns_id:-}" && "${ns_id:-}" != "None" ]]; then
		echo "Deleting Service Discovery namespace: $ns_id"
		aws servicediscovery delete-namespace --id "$ns_id" >/dev/null 2>&1 || true
	fi
	
	# Delete ElastiCache clusters (Redis for checkout)
	echo "Cleaning up ElastiCache clusters..."
	for cluster in $(aws elasticache describe-cache-clusters --region "$AWS_REGION" --query "CacheClusters[?contains(CacheClusterId, '${NAME_PREFIX}') || contains(CacheClusterId, 'checkout')].CacheClusterId" --output text 2>/dev/null); do
		[[ -n "$cluster" ]] || continue
		echo "Deleting ElastiCache cluster: $cluster"
		aws elasticache delete-cache-cluster --cache-cluster-id "$cluster" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete Amazon MQ brokers
	echo "Cleaning up Amazon MQ brokers..."
	for broker in $(aws mq list-brokers --region "$AWS_REGION" --query "BrokerSummaries[?contains(BrokerName, '${NAME_PREFIX}') || contains(BrokerName, 'orders')].BrokerId" --output text 2>/dev/null); do
		[[ -n "$broker" ]] || continue
		echo "Deleting Amazon MQ broker: $broker"
		aws mq delete-broker --broker-id "$broker" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete security groups (RDS security group and others)
	echo "Cleaning up security groups..."
	for sg_id in $(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${NAME_PREFIX}*" --query 'SecurityGroups[].GroupId' --output text 2>/dev/null); do
		[[ -n "$sg_id" ]] || continue
		# Skip default security groups
		if [[ "$sg_id" == "None" ]]; then
			continue
		fi
		echo "Deleting security group: $sg_id"
		aws ec2 delete-security-group --group-id "$sg_id" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	
	# Delete DB subnet group
	aws rds delete-db-subnet-group --db-subnet-group-name "${NAME_PREFIX}-db-subnet-group" --region "$AWS_REGION" >/dev/null 2>&1 || true

	echo "Fallback cleanup completed. Some dependencies (for example ENIs/VPC) may still require manual deletion."
}

report_leftovers() {
	echo
	echo "Post-cleanup leftover resource report"
	echo "------------------------------------"

	if [[ -n "$LEFTOVER_ENI_ID" ]]; then
		echo "Inspecting requested ENI: $LEFTOVER_ENI_ID"
		aws ec2 describe-network-interfaces \
			--network-interface-ids "$LEFTOVER_ENI_ID" \
			--region "$AWS_REGION" \
			--query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Type:InterfaceType,RequesterManaged:RequesterManaged,AttachmentId:Attachment.AttachmentId,InstanceId:Attachment.InstanceId,Description:Description,VpcId:VpcId,SubnetId:SubnetId}' \
			--output table 2>/dev/null || echo "Unable to describe ENI $LEFTOVER_ENI_ID (already removed or access denied)."
		echo
	fi

	# Check for leftover EKS clusters
	echo "Checking for leftover EKS clusters..."
	eks_clusters=$(aws eks list-clusters --region "$AWS_REGION" --query "clusters[?contains(@, '${CLUSTER_NAME}') || contains(@, '${NAME_PREFIX}')]" --output text 2>/dev/null || true)
	if [[ -n "${eks_clusters:-}" ]]; then
		echo "WARNING: Found EKS clusters that may need manual deletion:"
		for cluster in $eks_clusters; do
			echo "  - $cluster"
		done
	else
		echo "No leftover EKS clusters found."
	fi
	echo

	# Check for leftover RDS instances
	echo "Checking for leftover RDS instances..."
	rds_instances=$(aws rds describe-db-instances --region "$AWS_REGION" --query "DBInstances[?contains(DBInstanceIdentifier, '${NAME_PREFIX}')].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine}" --output table 2>/dev/null || true)
	if [[ -n "${rds_instances:-}" && "$rds_instances" != "None" ]]; then
		echo "WARNING: Found RDS instances that may need manual deletion:"
		echo "$rds_instances"
	else
		echo "No leftover RDS instances found."
	fi
	echo

	# Check for leftover DynamoDB tables
	echo "Checking for leftover DynamoDB tables..."
	ddb_tables=$(aws dynamodb list-tables --region "$AWS_REGION" --query "TableNames[?contains(@, '${DDB_TABLE}') || contains(@, 'retail')]" --output text 2>/dev/null || true)
	if [[ -n "${ddb_tables:-}" && "$ddb_tables" != "None" ]]; then
		echo "WARNING: Found DynamoDB tables that may need manual deletion:"
		for table in $ddb_tables; do
			echo "  - $table"
		done
	else
		echo "No leftover DynamoDB tables found."
	fi
	echo

	# Check for leftover IAM roles
	echo "Checking for leftover IAM roles..."
	iam_roles=$(aws iam list-roles --query "Roles[?contains(RoleName, '${NAME_PREFIX}') || contains(RoleName, 'lambda_exec') || contains(RoleName, 'adot')].RoleName" --output text 2>/dev/null || true)
	if [[ -n "${iam_roles:-}" && "$iam_roles" != "None" ]]; then
		echo "WARNING: Found IAM roles that may need manual deletion:"
		for role in $iam_roles; do
			echo "  - $role"
		done
	else
		echo "No leftover IAM roles found."
	fi
	echo

	# Check for leftover S3 buckets
	echo "Checking for leftover S3 buckets..."
	s3_buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, '${NAME_PREFIX}') || contains(Name, 'bedrock') || contains(Name, 'tfstate')].Name" --output text 2>/dev/null || true)
	if [[ -n "${s3_buckets:-}" && "$s3_buckets" != "None" ]]; then
		echo "WARNING: Found S3 buckets that may need manual deletion:"
		for bucket in $s3_buckets; do
			echo "  - $bucket"
		done
	else
		echo "No leftover S3 buckets found."
	fi
	echo

	# Check for leftover ElastiCache clusters
	echo "Checking for leftover ElastiCache clusters..."
	ec_clusters=$(aws elasticache describe-cache-clusters --region "$AWS_REGION" --query "CacheClusters[?contains(CacheClusterId, '${NAME_PREFIX}') || contains(CacheClusterId, 'checkout')].{ID:CacheClusterId,Status:CacheClusterStatus,Engine:Engine}" --output table 2>/dev/null || true)
	if [[ -n "${ec_clusters:-}" && "$ec_clusters" != "None" ]]; then
		echo "WARNING: Found ElastiCache clusters that may need manual deletion:"
		echo "$ec_clusters"
	else
		echo "No leftover ElastiCache clusters found."
	fi
	echo

	# Check for leftover Amazon MQ brokers
	echo "Checking for leftover Amazon MQ brokers..."
	mq_brokers=$(aws mq list-brokers --region "$AWS_REGION" --query "BrokerSummaries[?contains(BrokerName, '${NAME_PREFIX}') || contains(BrokerName, 'orders')].{ID:BrokerId,Name:BrokerName,Status:BrokerState}" --output table 2>/dev/null || true)
	if [[ -n "${mq_brokers:-}" && "$mq_brokers" != "None" ]]; then
		echo "WARNING: Found Amazon MQ brokers that may need manual deletion:"
		echo "$mq_brokers"
	else
		echo "No leftover Amazon MQ brokers found."
	fi
	echo

	# Check for leftover CloudWatch log groups
	echo "Checking for leftover CloudWatch log groups..."
	cw_logs=$(aws logs describe-log-groups --region "$AWS_REGION" --log-group-name-prefix "/aws/eks" --query "logGroups[].logGroupName" --output text 2>/dev/null || true)
	cw_logs2=$(aws logs describe-log-groups --region "$AWS_REGION" --log-group-name-prefix "${NAME_PREFIX}" --query "logGroups[].logGroupName" --output text 2>/dev/null || true)
	combined_logs="$(printf '%s\n%s\n' "$cw_logs" "$cw_logs2" | tr '\t' '\n' | awk 'NF' | sort -u)"
	if [[ -n "${combined_logs:-}" ]]; then
		echo "WARNING: Found CloudWatch log groups that may need manual deletion:"
		for log in $combined_logs; do
			echo "  - $log"
		done
	else
		echo "No leftover CloudWatch log groups found."
	fi
	echo

	# Check for leftover security groups
	echo "Checking for leftover security groups..."
	sgs=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${NAME_PREFIX}*" --query 'SecurityGroups[].{Id:GroupId,Name:GroupName,Description:Description}' --output table 2>/dev/null || true)
	if [[ -n "${sgs:-}" && "$sgs" != "None" ]]; then
		echo "WARNING: Found security groups that may need manual deletion:"
		echo "$sgs"
	else
		echo "No leftover security groups found."
	fi
	echo

	# Check VPCs with our tags
	local vpc_ids_by_name vpc_ids_by_tag combined_vpc_ids
	vpc_ids_by_name="$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)"
	vpc_ids_by_tag="$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_TAG" --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)"
	combined_vpc_ids="$(printf '%s\n%s\n' "$vpc_ids_by_name" "$vpc_ids_by_tag" | tr '\t' '\n' | awk 'NF' | sort -u | tr '\n' ' ')"

	if [[ -z "${combined_vpc_ids// }" ]]; then
		echo "No VPCs found by Name=$VPC_NAME or Project=$PROJECT_TAG."
	else
		for vpc_id in $combined_vpc_ids; do
			echo "VPC: $vpc_id"

			echo "  - In-use network interfaces"
			aws ec2 describe-network-interfaces \
				--region "$AWS_REGION" \
				--filters "Name=vpc-id,Values=$vpc_id" "Name=status,Values=in-use" \
				--query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Type:InterfaceType,Attachment:Attachment.InstanceId,Description:Description,Subnet:SubnetId}' \
				--output table 2>/dev/null || true

			echo "  - Load balancers in VPC"
			aws elbv2 describe-load-balancers \
				--region "$AWS_REGION" \
				--query "LoadBalancers[?VpcId=='$vpc_id'].{Name:LoadBalancerName,Type:Type,State:State.Code,DNS:DNSName}" \
				--output table 2>/dev/null || true

			echo "  - NAT gateways in VPC"
			aws ec2 describe-nat-gateways \
				--region "$AWS_REGION" \
				--filter "Name=vpc-id,Values=$vpc_id" \
				--query 'NatGateways[].{Id:NatGatewayId,State:State,Subnet:SubnetId}' \
				--output table 2>/dev/null || true

			echo "  - VPC endpoints in VPC"
			aws ec2 describe-vpc-endpoints \
				--region "$AWS_REGION" \
				--filters "Name=vpc-id,Values=$vpc_id" \
				--query 'VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName,State:State,Vpc:VpcId}' \
				--output table 2>/dev/null || true

			echo
		done
	fi
}


# 1. Delete Kubernetes resources (namespace deletes all in it), only if cluster is reachable
if kubectl version --short &>/dev/null; then
	echo "Deleting retail Helm release (if present)..."
	helm uninstall retail -n retail-app || true

	echo "Deleting Kubernetes namespace retail-app..."
	kubectl delete namespace retail-app --ignore-not-found

	# 2. Delete AWS Load Balancer Controller (if present)
	echo "Deleting AWS Load Balancer Controller (if present)..."
	helm uninstall aws-load-balancer-controller -n kube-system || true

	# 3. Delete Istio Helm releases (if present)
	echo "Deleting Istio Helm releases (if present)..."
	helm uninstall istio-ingress -n istio-ingress || true
	helm uninstall istiod -n istio-system || true
	helm uninstall istio-base -n istio-system || true
	kubectl delete namespace istio-system --ignore-not-found
	kubectl delete namespace istio-ingress --ignore-not-found
else
	echo "Kubernetes cluster not reachable. Skipping kubectl and helm cleanup."
fi

# 3. Destroy Terraform-managed AWS infrastructure
echo "Destroying Terraform infrastructure..."
pushd "$(dirname "$0")/../terraform" >/dev/null
set +e
TF_DESTROY_OUTPUT=$(terraform destroy -auto-approve 2>&1)
TF_DESTROY_EXIT=$?
set -e
popd >/dev/null

echo "$TF_DESTROY_OUTPUT"

if [[ $TF_DESTROY_EXIT -ne 0 ]] && echo "$TF_DESTROY_OUTPUT" | grep -Eq 'Unable to access object.*terraform.tfstate.*(Forbidden|NoSuchBucket|AccessDenied)|S3 bucket ".*" does not exist|NoSuchBucket'; then
	echo
	echo "[WARNING] Terraform could not access the S3 backend state."
	manual_fallback_cleanup
elif [[ $TF_DESTROY_EXIT -ne 0 ]]; then
	echo "[WARNING] Terraform destroy failed for a non-backend reason. Manual cleanup may still be required."
fi

# 4. Delete S3 bucket for Terraform state if it exists
delete_bucket_if_exists "$TFSTATE_BUCKET"

# 5. Report resources that may still block complete teardown
report_leftovers

echo "Cleanup complete."
