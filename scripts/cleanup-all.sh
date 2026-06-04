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

manual_fallback_cleanup() {
	echo "Running fallback AWS cleanup for known Bedrock resources..."

	# EKS resources
	for ng in $(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups[]' --output text 2>/dev/null); do
		echo "Deleting EKS node group: $ng"
		aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION" >/dev/null 2>&1 || true
	done
	aws eks delete-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || true

	# Data layer
	aws rds delete-db-instance --db-instance-identifier "${NAME_PREFIX}-catalog-mysql" --skip-final-snapshot --delete-automated-backups --region "$AWS_REGION" >/dev/null 2>&1 || true
	aws rds delete-db-instance --db-instance-identifier "${NAME_PREFIX}-orders-postgres" --skip-final-snapshot --delete-automated-backups --region "$AWS_REGION" >/dev/null 2>&1 || true
	aws dynamodb delete-table --table-name "$DDB_TABLE" --region "$AWS_REGION" >/dev/null 2>&1 || true

	aws secretsmanager delete-secret --secret-id "${NAME_PREFIX}/catalog-db" --force-delete-without-recovery --region "$AWS_REGION" >/dev/null 2>&1 || true
	aws secretsmanager delete-secret --secret-id "${NAME_PREFIX}/orders-db" --force-delete-without-recovery --region "$AWS_REGION" >/dev/null 2>&1 || true

	# Lambda and assets
	aws lambda delete-function --function-name "$LAMBDA_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || true
	delete_bucket_if_exists "$ASSETS_BUCKET"

	# IAM user cleanup (developer user)
	for key_id in $(aws iam list-access-keys --user-name "$IAM_USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
		aws iam delete-access-key --user-name "$IAM_USER" --access-key-id "$key_id" >/dev/null 2>&1 || true
	done
	aws iam delete-login-profile --user-name "$IAM_USER" >/dev/null 2>&1 || true
	aws iam detach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess >/dev/null 2>&1 || true
	aws iam delete-user-policy --user-name "$IAM_USER" --policy-name "${IAM_USER}-s3-put-object" >/dev/null 2>&1 || true
	aws iam delete-user --user-name "$IAM_USER" >/dev/null 2>&1 || true

	echo "Fallback cleanup attempted. Some dependencies (for example ENIs/VPC) may still require manual deletion."
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

	local vpc_ids_by_name vpc_ids_by_tag combined_vpc_ids
	vpc_ids_by_name="$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)"
	vpc_ids_by_tag="$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_TAG" --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)"
	combined_vpc_ids="$(printf '%s\n%s\n' "$vpc_ids_by_name" "$vpc_ids_by_tag" | tr '\t' '\n' | awk 'NF' | sort -u | tr '\n' ' ')"

	if [[ -z "${combined_vpc_ids// }" ]]; then
		echo "No VPCs found by Name=$VPC_NAME or Project=$PROJECT_TAG."
		return 0
	fi

	for vpc_id in $combined_vpc_ids; do
		echo "VPC: $vpc_id"

		echo "- In-use network interfaces"
		aws ec2 describe-network-interfaces \
			--region "$AWS_REGION" \
			--filters "Name=vpc-id,Values=$vpc_id" "Name=status,Values=in-use" \
			--query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Type:InterfaceType,Attachment:Attachment.InstanceId,Description:Description,Subnet:SubnetId}' \
			--output table 2>/dev/null || true

		echo "- Load balancers in VPC"
		aws elbv2 describe-load-balancers \
			--region "$AWS_REGION" \
			--query "LoadBalancers[?VpcId=='$vpc_id'].{Name:LoadBalancerName,Type:Type,State:State.Code,DNS:DNSName}" \
			--output table 2>/dev/null || true

		echo "- NAT gateways in VPC"
		aws ec2 describe-nat-gateways \
			--region "$AWS_REGION" \
			--filter "Name=vpc-id,Values=$vpc_id" \
			--query 'NatGateways[].{Id:NatGatewayId,State:State,Subnet:SubnetId}' \
			--output table 2>/dev/null || true

		echo "- VPC endpoints in VPC"
		aws ec2 describe-vpc-endpoints \
			--region "$AWS_REGION" \
			--filters "Name=vpc-id,Values=$vpc_id" \
			--query 'VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName,State:State,Vpc:VpcId}' \
			--output table 2>/dev/null || true

		echo
	done
}


# 1. Delete Kubernetes resources (namespace deletes all in it), only if cluster is reachable
if kubectl version --short &>/dev/null; then
	echo "Deleting Kubernetes namespace retail-app..."
	kubectl delete namespace retail-app --ignore-not-found

	# 2. Delete Istio Helm releases (if present)
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
