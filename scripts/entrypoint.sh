#!/bin/bash
# Terraform Cloudflare Action - Entrypoint Script
# Follows SMART and DRY principles with comprehensive safety mechanisms

set -euo pipefail

#==============================================================================
# CONFIGURATION AND CONSTANTS
#==============================================================================
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
# HELPER FUNCTIONS (DRY Principle)
#==============================================================================

# Safely write to GITHUB_OUTPUT if available (for local testing support)
write_github_output() {
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "$1" >> "$GITHUB_OUTPUT"
    fi
}

# Add arguments from string to array safely (avoids shellcheck SC2206)
# Args:
#   $1: Name of the array variable to append to (passed by reference)
#   $2: String containing space-separated arguments
add_args_from_string() {
    local -n arr=$1
    local str=$2
    if [[ -n "$str" ]]; then
        local args_array
        IFS=' ' read -ra args_array <<< "$str"
        arr+=("${args_array[@]}")
    fi
}

#==============================================================================
# VALIDATION FUNCTIONS
#==============================================================================
# Validates that all required input parameters are provided
# Exits with code 1 if any required inputs are missing
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
        log_error "Please ensure these inputs are set in your workflow configuration"
        exit 1
    fi
    
    log_success "All required inputs validated"
}

# Validates that the specified Terraform action is supported
# Args: None (uses INPUT_TERRAFORM_ACTION environment variable)
# Exits with code 1 if the action is not valid
validate_action() {
    local action="${INPUT_TERRAFORM_ACTION:-plan}"
    local -r valid_actions=("plan" "apply" "destroy" "import" "validate" "output" "init")
    
    local is_valid=false
    for valid in "${valid_actions[@]}"; do
        if [[ "$action" == "$valid" ]]; then
            is_valid=true
            break
        fi
    done
    
    if [[ "$is_valid" == "false" ]]; then
        log_error "Invalid terraform action: '$action'"
        log_error "Valid actions are: ${valid_actions[*]}"
        exit 1
    fi
    
    log_info "Terraform action: $action"
}

# Validates and changes to the working directory
# Args: None (uses INPUT_WORKING_DIRECTORY environment variable)
# Exits with code 1 if the directory doesn't exist or can't be accessed
validate_working_directory() {
    local working_dir="${INPUT_WORKING_DIRECTORY:-.}"
    
    if [[ ! -d "$working_dir" ]]; then
        log_error "Working directory does not exist: $working_dir"
        log_error "Please ensure the path is correct and the directory exists"
        exit 1
    fi
    
    if ! cd "$working_dir" 2>/dev/null; then
        log_error "Unable to access working directory: $working_dir"
        exit 1
    fi
    
    log_info "Working directory: $(pwd)"
}

#==============================================================================
# TERRAFORM HELPER FUNCTIONS (DRY Principle)
#==============================================================================
# Executes a Terraform command with the specified arguments
# Args:
#   $1: Terraform command (e.g., "init", "plan", "apply")
#   $@: Additional arguments to pass to the command
# Returns: Exit code from Terraform command
run_terraform() {
    local cmd="$1"
    shift
    local args=("$@")
    
    log_info "Running: terraform $cmd ${args[*]:-}"
    terraform "$cmd" "${args[@]:-}" 2>&1
}

# Configures Terraform variables from file or inline input
# Supports both external tfvars files and inline variable definitions
# Exports TFVARS_ARGS for use in subsequent Terraform commands
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
            log_error "Please verify the file path is correct"
            exit 1
        fi
    fi
    
    # Handle inline tfvars
    if [[ -n "${INPUT_TFVARS:-}" ]]; then
        # Create a secure temporary tfvars file from inline variables
        local temp_tfvars
        temp_tfvars=$(mktemp /tmp/inline.XXXXXX.auto.tfvars) || {
            log_error "Failed to create temporary tfvars file"
            exit 1
        }
        if ! echo "${INPUT_TFVARS}" > "$temp_tfvars"; then
            log_error "Failed to write to temporary tfvars file"
            rm -f "$temp_tfvars"
            exit 1
        fi
        tfvars_args+=("-var-file=$temp_tfvars")
        log_info "Created inline tfvars file: $temp_tfvars"
    fi
    
    # Export for use in other functions
    export TFVARS_ARGS="${tfvars_args[*]:-}"
    log_success "Terraform variables configured"
}

# Configures Terraform backend settings from newline-separated key=value pairs
# Exports BACKEND_CONFIG_ARGS for use in terraform init command
setup_backend_config() {
    if [[ -z "${INPUT_BACKEND_CONFIG:-}" ]]; then
        return 0
    fi
    
    log_step "Setting up Backend Configuration"
    
    local backend_args=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
            backend_args+=("-backend-config=$line")
            # Mask potential sensitive values in logs (case-insensitive matching)
            local display_line="$line"
            local line_lower="${line,,}"  # Convert to lowercase for comparison
            if [[ "$line_lower" =~ (password|secret|token|key|credentials)= ]]; then
                display_line="${line%%=*}=***"
            fi
            log_info "Backend config: $display_line"
        fi
    done <<< "${INPUT_BACKEND_CONFIG}"
    
    export BACKEND_CONFIG_ARGS="${backend_args[*]:-}"
    log_success "Backend configuration set"
}

#==============================================================================
# SAFETY MECHANISMS
#==============================================================================
# Enforces destroy protection to prevent accidental resource destruction
# Requires both auto_approve=true and destroy_protection=false for destroy operations
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

# Detects configuration drift between Terraform state and actual infrastructure
# Uses refresh-only plan to identify any discrepancies without making changes
detect_drift() {
    if [[ "${INPUT_ENABLE_DRIFT_DETECTION:-true}" != "true" ]]; then
        return 0
    fi
    
    log_step "Detecting Configuration Drift"
    
    local plan_args=("-input=false" "-refresh-only" "-detailed-exitcode")
    
    add_args_from_string plan_args "${TFVARS_ARGS:-}"
    
    local drift_exit_code=0
    terraform plan "${plan_args[@]}" 2>&1 || drift_exit_code=$?
    
    case $drift_exit_code in
        0)
            log_success "No drift detected - state is in sync"
            ;;
        1)
            log_warning "Error during drift detection"
            log_warning "This may indicate a problem with the Terraform configuration or state"
            ;;
        2)
            log_warning "Drift detected - configuration differs from remote state"
            log_warning "Review the output above to see what has changed outside of Terraform"
            ;;
        *)
            log_warning "Unexpected exit code from drift detection: $drift_exit_code"
            ;;
    esac
    
    log_success "Drift detection completed"
}

# Analyzes and summarizes a Terraform plan file
# Provides detailed counts of resources to create, update, and delete
# Args:
#   $1: Path to the Terraform plan file
analyze_plan() {
    local plan_file="$1"
    
    if [[ ! -f "$plan_file" ]]; then
        log_warning "Plan file not found: $plan_file"
        return 0
    fi
    
    log_step "Analyzing Terraform Plan"
    
    local plan_output
    plan_output=$(terraform show -json "$plan_file" 2>/dev/null || true)
    
    if [[ -z "$plan_output" ]]; then
        log_warning "Could not analyze plan output"
        log_warning "The plan file may be invalid or Terraform may not be configured correctly"
        return 0
    fi
    
    # Parse changes using jq if available
    if command -v jq &> /dev/null; then
        local create_count update_count delete_count total_changes
        create_count=$(echo "$plan_output" | jq '[.resource_changes[]? | select(.change.actions[] == "create")] | length' 2>/dev/null || echo "0")
        update_count=$(echo "$plan_output" | jq '[.resource_changes[]? | select(.change.actions[] == "update")] | length' 2>/dev/null || echo "0")
        delete_count=$(echo "$plan_output" | jq '[.resource_changes[]? | select(.change.actions[] == "delete")] | length' 2>/dev/null || echo "0")
        total_changes=$((create_count + update_count + delete_count))
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "PLAN SUMMARY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "  ${GREEN}+ Create:${NC} $create_count resources"
        echo -e "  ${YELLOW}~ Update:${NC} $update_count resources"
        echo -e "  ${RED}- Delete:${NC} $delete_count resources"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Set GitHub Action outputs - check if there are actual changes
        local has_changes="false"
        if [[ "$total_changes" -gt 0 ]]; then
            has_changes="true"
        fi
        
        write_github_output "plan_has_changes=$has_changes"
        write_github_output "plan_summary=Create: $create_count, Update: $update_count, Delete: $delete_count"
        
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
# Imports existing Cloudflare resources into Terraform state
# Processes newline-separated resource_address=cloudflare_id pairs
# Exits with code 1 if any imports fail
import_resources() {
    if [[ -z "${INPUT_IMPORT_RESOURCES:-}" ]]; then
        return 0
    fi
    
    log_step "Importing Existing Cloudflare Resources"
    
    local imported_resources=()
    local failed_imports=()
    local tfvars_arr=()
    add_args_from_string tfvars_arr "${TFVARS_ARGS:-}"
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Validate format: must have exactly one equals sign
        # Count equals signs using bash string manipulation
        local temp="${line//[^=]}"
        local equals_count="${#temp}"
        if [[ "$equals_count" -ne 1 ]]; then
            log_warning "Skipping malformed import line: $line"
            log_warning "Expected format: resource_address=cloudflare_id (exactly one '=' character)"
            continue
        fi
        
        # Ensure both parts are non-empty
        if [[ ! "$line" =~ ^[^=]+=[^=]+$ ]]; then
            log_warning "Skipping invalid import line: $line"
            log_warning "Both resource address and cloudflare ID must be non-empty"
            continue
        fi
        
        # Parse resource format: resource_address=cloudflare_id
        local resource_address="${line%%=*}"
        local cloudflare_id="${line#*=}"
        
        log_info "Importing: $resource_address from $cloudflare_id"
        
        if terraform import "${tfvars_arr[@]}" "$resource_address" "$cloudflare_id" 2>&1; then
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
        write_github_output "imported_resources=${imported_resources[*]}"
    fi
    
    if [[ ${#failed_imports[@]} -gt 0 ]]; then
        log_error "Failed to import ${#failed_imports[@]} resource(s): ${failed_imports[*]}"
        log_error "Please verify the resource addresses and IDs are correct"
        exit 1
    fi
    
    if [[ ${#imported_resources[@]} -eq 0 ]] && [[ ${#failed_imports[@]} -eq 0 ]]; then
        log_warning "No valid import statements found"
        log_info "Use format: resource_address=cloudflare_id (one per line)"
    fi
}

#==============================================================================
# CORE TERRAFORM OPERATIONS
#==============================================================================
# Initializes Terraform working directory and downloads providers
# Applies backend configuration if provided
# Exits with code 1 if initialization fails
terraform_init() {
    log_step "Initializing Terraform"
    
    local init_args=("-input=false")
    
    add_args_from_string init_args "${BACKEND_CONFIG_ARGS:-}"
    
    if ! terraform init "${init_args[@]}"; then
        log_error "Terraform init failed"
        log_error "This could be due to:"
        log_error "  - Invalid Terraform configuration"
        log_error "  - Incorrect backend configuration"
        log_error "  - Network issues downloading providers"
        exit 1
    fi
    
    log_success "Terraform initialized successfully"
}

# Validates the Terraform configuration for syntax and consistency
# Exits with code 1 if validation fails
terraform_validate() {
    log_step "Validating Terraform Configuration"
    
    if ! terraform validate; then
        log_error "Terraform validation failed"
        log_error "Please review the configuration for syntax errors or invalid references"
        exit 1
    fi
    
    log_success "Terraform configuration is valid"
}

# Creates a Terraform execution plan showing proposed changes
# Outputs plan to a file for potential later use with apply
# Exits with code 1 if plan creation fails
terraform_plan() {
    log_step "Creating Terraform Plan"
    
    local plan_args=("-input=false" "-out=${PLAN_FILE}")
    
    add_args_from_string plan_args "${TFVARS_ARGS:-}"
    
    if [[ -n "${INPUT_MAX_PARALLELISM:-}" ]]; then
        if [[ "${INPUT_MAX_PARALLELISM}" =~ ^[0-9]+$ ]]; then
            # Limit parallelism to reasonable range (1-50)
            if [[ "${INPUT_MAX_PARALLELISM}" -ge 1 ]] && [[ "${INPUT_MAX_PARALLELISM}" -le 50 ]]; then
                plan_args+=("-parallelism=${INPUT_MAX_PARALLELISM}")
            else
                log_warning "max_parallelism must be between 1 and 50, using default"
            fi
        else
            log_warning "max_parallelism must be a number, ignoring invalid value"
        fi
    fi
    
    local plan_output
    plan_output=$(terraform plan "${plan_args[@]}" 2>&1) || {
        log_error "Terraform plan failed"
        echo "$plan_output"
        exit 1
    }
    
    echo "$plan_output"
    
    # Capture plan output for GitHub Actions
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        {
            echo 'plan_output<<EOF'
            echo "$plan_output"
            echo 'EOF'
        } >> "$GITHUB_OUTPUT"
    fi
    
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
        log_info "Auto-approve is disabled. Skipping apply step and running plan only for review. No changes will be applied."
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
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        {
            echo 'apply_output<<EOF'
            echo "$apply_output"
            echo 'EOF'
        } >> "$GITHUB_OUTPUT"
    fi
    
    # Capture state outputs
    local state_outputs
    state_outputs=$(terraform output -json 2>/dev/null || echo "{}")
    write_github_output "state_outputs=$state_outputs"
    
    log_success "Terraform apply completed successfully"
}

# Destroys all Terraform-managed infrastructure
# Requires both auto_approve=true and destroy_protection=false
# Exits with code 1 if destruction fails
terraform_destroy() {
    log_step "Destroying Terraform Resources"
    
    # Safety check for destroy protection
    check_destroy_protection
    
    local destroy_args=("-input=false")
    
    if [[ "${INPUT_AUTO_APPROVE:-false}" == "true" ]]; then
        destroy_args+=("-auto-approve")
        log_warning "Auto-approve enabled for DESTRUCTIVE operation"
    else
        log_error "Destroy requires auto_approve=true"
        log_error "This is a safety mechanism to prevent accidental destruction"
        exit 1
    fi
    
    add_args_from_string destroy_args "${TFVARS_ARGS:-}"
    
    if [[ -n "${INPUT_MAX_PARALLELISM:-}" ]]; then
        if [[ "${INPUT_MAX_PARALLELISM}" =~ ^[0-9]+$ ]]; then
            # Limit parallelism to reasonable range (1-50)
            if [[ "${INPUT_MAX_PARALLELISM}" -ge 1 ]] && [[ "${INPUT_MAX_PARALLELISM}" -le 50 ]]; then
                destroy_args+=("-parallelism=${INPUT_MAX_PARALLELISM}")
            else
                log_warning "max_parallelism must be between 1 and 50, using default"
            fi
        else
            log_warning "max_parallelism must be a number, ignoring invalid value"
        fi
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

# Retrieves all Terraform output values from the state
# Returns empty JSON object if no outputs exist or if state is not initialized
terraform_output() {
    log_step "Getting Terraform Outputs"
    
    local state_outputs
    state_outputs=$(terraform output -json 2>/dev/null || echo "{}")
    
    echo "$state_outputs"
    write_github_output "state_outputs=$state_outputs"
    
    log_success "Terraform outputs retrieved"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================
# Main entry point for the Terraform Cloudflare Action
# Coordinates validation, initialization, and execution of the requested Terraform action
# Args:
#   $@: Command-line arguments (currently unused, reserved for future use)
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
            # Already handled above, now generate plan to verify imports
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
