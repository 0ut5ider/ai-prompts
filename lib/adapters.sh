# ABOUTME: Shared adapter constants, state variables, and loader functions.
# ABOUTME: Sourced by installer scripts after SCRIPT_DIR is set. Provides discover_adapters() and load_adapter().

# ─── Constants ────────────────────────────────────────────────────────────────
ADAPTERS_DIR="${SCRIPT_DIR}/adapters"

# Neutral source directory name (inside sub-sources)
NEUTRAL_CONFIG_DIR=".agent"
# Neutral rules file name (at sub-source root)
NEUTRAL_RULES_FILE="RULES.md"
# Neutral settings file name (at sub-source root)
NEUTRAL_SETTINGS_FILE="settings.yaml"

# ─── Adapter state (populated by load_adapter) ──────────────────────────────
ADAPTER_NAME=""
ADAPTER_LABEL=""
CONFIG_DIR=""
RULES_FILE=""
SETTINGS_FILE=""
SETTINGS_LOCATION=""  # "root" or "config_dir"
SUPPORTED_SUBDIRS=()
GLOBAL_CONFIG_DIR=""   # global config directory (used by global installs)

# ─── Dependency check ─────────────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    for cmd in jq yq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[ERROR] Missing required dependencies: ${missing[*]}"
        echo "Install them and try again."
        exit 1
    fi
}

# ─── Adapter functions ────────────────────────────────────────────────────────
discover_adapters() {
    local adapters=()
    for file in "${ADAPTERS_DIR}"/*.sh; do
        [[ -f "$file" ]] || continue
        local name
        name="$(basename "$file" .sh)"
        adapters+=("$name")
    done
    printf '%s\n' "${adapters[@]}"
}

load_adapter() {
    local adapter_name="$1"
    local adapter_file="${ADAPTERS_DIR}/${adapter_name}.sh"

    if [[ ! -f "$adapter_file" ]]; then
        error "Adapter '${adapter_name}' not found at '${adapter_file}'"
        exit 1
    fi

    # Reset state from any previously loaded adapter
    ADAPTER_NAME=""
    ADAPTER_LABEL=""
    CONFIG_DIR=""
    RULES_FILE=""
    SETTINGS_FILE=""
    SETTINGS_LOCATION=""
    SUPPORTED_SUBDIRS=()
    GLOBAL_CONFIG_DIR=""
    unset -f transform_settings 2>/dev/null || true

    # shellcheck source=/dev/null
    source "$adapter_file"

    # Validate adapter contract
    local missing_fields=()
    [[ -z "$ADAPTER_NAME" ]]  && missing_fields+=("ADAPTER_NAME")
    [[ -z "$ADAPTER_LABEL" ]] && missing_fields+=("ADAPTER_LABEL")
    [[ -z "$CONFIG_DIR" ]]    && missing_fields+=("CONFIG_DIR")
    [[ -z "$RULES_FILE" ]]    && missing_fields+=("RULES_FILE")
    [[ -z "$SETTINGS_FILE" ]] && missing_fields+=("SETTINGS_FILE")
    [[ -z "$SETTINGS_LOCATION" ]] && missing_fields+=("SETTINGS_LOCATION")
    [[ ${#SUPPORTED_SUBDIRS[@]} -eq 0 ]] && missing_fields+=("SUPPORTED_SUBDIRS")
    [[ -z "$GLOBAL_CONFIG_DIR" ]]  && missing_fields+=("GLOBAL_CONFIG_DIR")

    if ! declare -f transform_settings &>/dev/null; then
        missing_fields+=("transform_settings()")
    fi

    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        error "Adapter '${adapter_name}' is missing required fields: ${missing_fields[*]}"
        exit 1
    fi

    if [[ "$SETTINGS_LOCATION" != "root" && "$SETTINGS_LOCATION" != "config_dir" ]]; then
        error "Adapter '${adapter_name}' has invalid SETTINGS_LOCATION='${SETTINGS_LOCATION}' (must be 'root' or 'config_dir')"
        exit 1
    fi
}
