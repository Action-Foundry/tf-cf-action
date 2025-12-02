#!/bin/bash
# Terraform Cloudflare Action - Entrypoint Script
# Follows SMART and DRY principles with comprehensive safety mechanisms

set -euo pipefail

#==============================================================================
# CONFIGURATION AND CONSTANTS
#==============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_PREFIX="[TF-CF-ACTION]"
readonly PLAN_FILE="${INPUT_PLAN_OUTPUT_FILE:-tfplan}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#==============================================================================
# LOGGING FUNCTIONS (DRY Principle)
#==============================================================================
log_info() {
    echo -e "${BLUE}${LOG_PREFIX} [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${LOG_PREFIX} [SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}${LOG_PREFIX} [WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}${LOG_PREFIX} [ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${LOG_PREFIX}${NC} $1"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

#==============================================================================
# VALIDATION FUNCTIONS
#==============================================================================
validate_required_inputs() {
    log_step "Validating Required Inputs"
    
    local missing_inputs=()
    
    if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        missing_inputs+=("cloudflare_api_token")
    fi
    
    if [[ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
        missing_inputs+=("cloudflare_account_id")
    fi
    
    if [[ ${#missing_inputs[@]} -gt 0 ]]; then
        log_error "Missing required inputs: ${missing_inputs[*]}"
        exit 1
    fi
    
    log_success "All required inputs validated"
}

validate_action() {
    local action="${INPUT_TERRAFORM_ACTION:-plan}"
    local valid_actions=("plan" "apply" "destroy" "import" "validate" "output" "init")
    
    local is_valid=false
    for valid in "${valid_actions[@]}"; do
        if [[ "$action" == "$valid" ]]; then
            is_valid=true
            break
        fi
    done
    
    if [[ "$is_valid" == "false" ]]; then
        log_error "Invalid terraform action: $action"
        log_error "Valid actions are: ${valid_actions[*]}"
        exit 1
    fi
    
    log_info "Terraform action: $action"
}

validate_working_directory() {
    local working_dir="${INPUT_WORKING_DIRECTORY:-.}"
    
    if [[ ! -d "$working_dir" ]]; then
        log_error "Working directory does not exist: $working_dir"
        exit 1
    fi
    
    cd "$working_dir"
    log_info "Working directory: $(pwd)"
}

#==============================================================================
# TERRAFORM HELPER FUNCTIONS (DRY Principle)
#==============================================================================
run_terraform() {
    local cmd="$1"
    shift
    local args=("$@")
    
    log_info "Running: terraform $cmd ${args[*]:-}"
    terraform "$cmd" "${args[@]:-}" 2>&1
}

setup_tfvars() {
    log_step "Setting up Terraform Variables"
    
    local tfvars_args=()
    
    # Handle tfvars file
    if [[ -n "${INPUT_TFVARS_FILE:-}" ]]; then
        if [[ -f "${INPUT_TFVARS_FILE}" ]]; then
            tfvars_args+=("-var-file=${INPUT_TFVARS_FILE}")
            log_info "Using tfvars file: ${INPUT_TFVARS_FILE}"
        else
            log_error "Specified tfvars file not found: ${INPUT_TFVARS_FILE}"
            exit 1
        fi
    fi
    
    # Handle inline tfvars
    if [[ -n "${INPUT_TFVARS:-}" ]]; then
        # Create a temporary tfvars file from inline variables
        local temp_tfvars="/tmp/inline.auto.tfvars"
        echo "${INPUT_TFVARS}" > "$temp_tfvars"
        tfvars_args+=("-var-file=$temp_tfvars")
        log_info "Created inline tfvars file"
    fi
    
    # Export for use in other functions
    export TFVARS_ARGS="${tfvars_args[*]:-}"
    log_success "Terraform variables configured"
}

setup_backend_config() {
    if [[ -z "${INPUT_BACKEND_CONFIG:-}" ]]; then
        return 0
    fi
    
    log_step "Setting up Backend Configuration"
    
    local backend_args=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            backend_args+=("-backend-config=$line")
            log_info "Backend config: $line"
        fi
    done <<< "${INPUT_BACKEND_CONFIG}"
    
    export BACKEND_CONFIG_ARGS="${backend_args[*]:-}"
    log_success "Backend configuration set"
}

#==============================================================================
# SAFETY MECHANISMS
#==============================================================================
check_destroy_protection() {
    local action="${INPUT_TERRAFORM_ACTION:-plan}"
    
    if [[ "$action" == "destroy" ]] && [[ "${INPUT_DESTROY_PROTECTION:-true}" == "true" ]]; then
        if [[ "${INPUT_AUTO_APPROVE:-false}" != "true" ]]; then
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_warning "DESTROY PROTECTION ENABLED"
            log_warning "You are attempting to destroy Cloudflare resources."
            log_warning "Set 'auto_approve: true' and 'destroy_protection: false'"
            log_warning "to proceed with destruction."
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 1
        fi
    fi
}

detect_drift() {
    if [[ "${INPUT_ENABLE_DRIFT_DETECTION:-true}" != "true" ]]; then
        return 0
    fi
    
    log_step "Detecting Configuration Drift"
    
    local refresh_output
    if ! refresh_output=$(terraform refresh ${TFVARS_ARGS:-} 2>&1); then
        log_warning "Could not refresh state for drift detection"
        echo "$refresh_output"
        return 0
    fi
    
    log_success "Drift detection completed"
}

analyze_plan() {
    local plan_file="$1"
    local plan_output
    
    log_step "Analyzing Terraform Plan"
    
    plan_output=$(terraform show -json "$plan_file" 2>/dev/null || true)
    
    if [[ -z "$plan_output" ]]; then
        log_warning "Could not analyze plan output"
        return 0
    fi
    
    # Parse changes using jq if available
    if command -v jq &> /dev/null; then
        local create_count update_count delete_count
        create_count=$(echo "$plan_output" | jq '[.resource_changes[]? | select(.change.actions[] == "create")] | length')
        update_count=$(echo "$plan_output" | jq '[.resource_changes[]? | select(.change.actions[] == "update")] | length')
        delete_count=$(echo "$plan_output" | jq '[.resource_changes[]? | select(.change.actions[] == "delete")] | length')
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "PLAN SUMMARY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "  ${GREEN}+ Create:${NC} $create_count resources"
        echo -e "  ${YELLOW}~ Update:${NC} $update_count resources"
        echo -e "  ${RED}- Delete:${NC} $delete_count resources"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Set GitHub Action outputs
        {
            echo "plan_has_changes=true"
            echo "plan_summary=Create: $create_count, Update: $update_count, Delete: $delete_count"
        } >> "$GITHUB_OUTPUT"
        
        # Warn about destructive changes
        if [[ "$delete_count" -gt 0 ]]; then
            log_warning "This plan includes $delete_count DESTRUCTIVE change(s)!"
            log_warning "Please review carefully before applying."
        fi
    else
        log_info "Install jq for detailed plan analysis"
    fi
}

#==============================================================================
# IMPORT FUNCTIONALITY
#==============================================================================
import_resources() {
    if [[ -z "${INPUT_IMPORT_RESOURCES:-}" ]]; then
        return 0
    fi
    
    log_step "Importing Existing Cloudflare Resources"
    
    local imported_resources=()
    local failed_imports=()
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        # Parse resource format: resource_address=cloudflare_id
        local resource_address="${line%%=*}"
        local cloudflare_id="${line#*=}"
        
        log_info "Importing: $resource_address from $cloudflare_id"
        
        if terraform import ${TFVARS_ARGS:-} "$resource_address" "$cloudflare_id" 2>&1; then
            imported_resources+=("$resource_address")
            log_success "Successfully imported: $resource_address"
        else
            failed_imports+=("$resource_address")
            log_error "Failed to import: $resource_address"
        fi
    done <<< "${INPUT_IMPORT_RESOURCES}"
    
    # Report results
    if [[ ${#imported_resources[@]} -gt 0 ]]; then
        log_success "Successfully imported ${#imported_resources[@]} resource(s)"
        echo "imported_resources=${imported_resources[*]}" >> "$GITHUB_OUTPUT"
    fi
    
    if [[ ${#failed_imports[@]} -gt 0 ]]; then
        log_error "Failed to import ${#failed_imports[@]} resource(s): ${failed_imports[*]}"
        exit 1
    fi
}

#==============================================================================
# CORE TERRAFORM OPERATIONS
#==============================================================================
terraform_init() {
    log_step "Initializing Terraform"
    
    local init_args=("-input=false")
    
    if [[ -n "${BACKEND_CONFIG_ARGS:-}" ]]; then
        # shellcheck disable=SC2206
        init_args+=($BACKEND_CONFIG_ARGS)
    fi
    
    if ! terraform init "${init_args[@]}"; then
        log_error "Terraform init failed"
        exit 1
    fi
    
    log_success "Terraform initialized successfully"
}

terraform_validate() {
    log_step "Validating Terraform Configuration"
    
    if ! terraform validate; then
        log_error "Terraform validation failed"
        exit 1
    fi
    
    log_success "Terraform configuration is valid"
}

terraform_plan() {
    log_step "Creating Terraform Plan"
    
    local plan_args=("-input=false" "-out=${PLAN_FILE}")
    
    if [[ -n "${TFVARS_ARGS:-}" ]]; then
        # shellcheck disable=SC2206
        plan_args+=($TFVARS_ARGS)
    fi
    
    if [[ -n "${INPUT_MAX_PARALLELISM:-}" ]]; then
        plan_args+=("-parallelism=${INPUT_MAX_PARALLELISM}")
    fi
    
    local plan_output
    plan_output=$(terraform plan "${plan_args[@]}" 2>&1) || {
        log_error "Terraform plan failed"
        echo "$plan_output"
        exit 1
    }
    
    echo "$plan_output"
    
    # Capture plan output for GitHub Actions
    {
        echo 'plan_output<<EOF'
        echo "$plan_output"
        echo 'EOF'
    } >> "$GITHUB_OUTPUT"
    
    # Analyze the plan
    analyze_plan "${PLAN_FILE}"
    
    log_success "Terraform plan completed successfully"
}

terraform_apply() {
    log_step "Applying Terraform Changes"
    
    local apply_args=("-input=false")
    
    # Check for auto-approve
    if [[ "${INPUT_AUTO_APPROVE:-false}" == "true" ]]; then
        apply_args+=("-auto-approve")
        log_warning "Auto-approve is enabled - changes will be applied without confirmation"
    else
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_warning "APPLY REQUIRES APPROVAL"
        log_warning "Set 'auto_approve: true' to apply changes automatically."
        log_warning "This is a safety mechanism to prevent accidental changes."
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Running plan only..."
        terraform_plan
        return 0
    fi
    
    if [[ -n "${INPUT_MAX_PARALLELISM:-}" ]]; then
        apply_args+=("-parallelism=${INPUT_MAX_PARALLELISM}")
    fi
    
    # Use plan file if it exists
    if [[ -f "${PLAN_FILE}" ]]; then
        apply_args+=("${PLAN_FILE}")
    else
        # First run a plan
        terraform_plan
        apply_args+=("${PLAN_FILE}")
    fi
    
    local apply_output
    apply_output=$(terraform apply "${apply_args[@]}" 2>&1) || {
        log_error "Terraform apply failed"
        echo "$apply_output"
        exit 1
    }
    
    echo "$apply_output"
    
    # Capture apply output
    {
        echo 'apply_output<<EOF'
        echo "$apply_output"
        echo 'EOF'
    } >> "$GITHUB_OUTPUT"
    
    # Capture state outputs
    local state_outputs
    state_outputs=$(terraform output -json 2>/dev/null || echo "{}")
    echo "state_outputs=$state_outputs" >> "$GITHUB_OUTPUT"
    
    log_success "Terraform apply completed successfully"
}

terraform_destroy() {
    log_step "Destroying Terraform Resources"
    
    # Safety check
    check_destroy_protection
    
    local destroy_args=("-input=false")
    
    if [[ "${INPUT_AUTO_APPROVE:-false}" == "true" ]]; then
        destroy_args+=("-auto-approve")
    else
        log_error "Destroy requires auto_approve=true"
        exit 1
    fi
    
    if [[ -n "${TFVARS_ARGS:-}" ]]; then
        # shellcheck disable=SC2206
        destroy_args+=($TFVARS_ARGS)
    fi
    
    if [[ -n "${INPUT_MAX_PARALLELISM:-}" ]]; then
        destroy_args+=("-parallelism=${INPUT_MAX_PARALLELISM}")
    fi
    
    local destroy_output
    destroy_output=$(terraform destroy "${destroy_args[@]}" 2>&1) || {
        log_error "Terraform destroy failed"
        echo "$destroy_output"
        exit 1
    }
    
    echo "$destroy_output"
    log_success "Terraform destroy completed successfully"
}

terraform_output() {
    log_step "Getting Terraform Outputs"
    
    local state_outputs
    state_outputs=$(terraform output -json 2>/dev/null || echo "{}")
    
    echo "$state_outputs"
    echo "state_outputs=$state_outputs" >> "$GITHUB_OUTPUT"
    
    log_success "Terraform outputs retrieved"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================
main() {
    log_step "Terraform Cloudflare Action - Starting"
    
    # Validate inputs and setup
    validate_required_inputs
    validate_action
    validate_working_directory
    setup_tfvars
    setup_backend_config
    
    # Initialize Terraform
    terraform_init
    
    # Run validation
    terraform_validate
    
    # Handle imports if specified
    if [[ -n "${INPUT_IMPORT_RESOURCES:-}" ]]; then
        import_resources
    fi
    
    # Execute requested action
    case "${INPUT_TERRAFORM_ACTION:-plan}" in
        "plan")
            detect_drift
            terraform_plan
            ;;
        "apply")
            detect_drift
            terraform_apply
            ;;
        "destroy")
            terraform_destroy
            ;;
        "import")
            if [[ -z "${INPUT_IMPORT_RESOURCES:-}" ]]; then
                log_error "No resources specified for import"
                log_info "Use 'import_resources' input with format: resource_address=cloudflare_id"
                exit 1
            fi
            # Already handled above
            terraform_plan
            ;;
        "validate")
            # Already validated above
            log_success "Configuration is valid"
            ;;
        "output")
            terraform_output
            ;;
        "init")
            # Already initialized above
            log_success "Initialization complete"
            ;;
        *)
            log_error "Unknown action: ${INPUT_TERRAFORM_ACTION}"
            exit 1
            ;;
    esac
    
    log_step "Terraform Cloudflare Action - Complete"
}

# Execute main function
main "$@"
