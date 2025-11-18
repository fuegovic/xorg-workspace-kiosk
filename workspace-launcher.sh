#!/bin/bash

# Xorg Workspace Kiosk - Launcher Script
# Launches applications across multiple workspaces in kiosk mode

# Configuration file location
CONFIG_FILE="$HOME/.config/workspaces.conf"

# Browser kiosk flags for reliability
CHROMIUM_BASE_FLAGS="--new-window --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble --disable-background-networking --disable-sync --disable-translate"
FIREFOX_BASE_FLAGS="--new-instance -kiosk"

# Parse configuration file
declare -A WORKSPACE_TYPES
declare -A WORKSPACE_URLS
declare -A WORKSPACE_COMMANDS
declare -A WORKSPACE_NAMES

parse_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "ERROR: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    local current_workspace=""
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Match workspace header
        if [[ "$line" =~ ^\[workspace-([0-9]+)\] ]]; then
            current_workspace="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Parse key-value pairs
        if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            case "$key" in
                type)
                    WORKSPACE_TYPES[$current_workspace]="$value"
                    ;;
                url)
                    WORKSPACE_URLS[$current_workspace]="$value"
                    ;;
                command)
                    WORKSPACE_COMMANDS[$current_workspace]="$value"
                    ;;
                name)
                    WORKSPACE_NAMES[$current_workspace]="$value"
                    ;;
            esac
        fi
    done < "$CONFIG_FILE"
    
    log "Loaded configuration for ${#WORKSPACE_TYPES[@]} workspace(s)"
}

# Logging
LOG_FILE="$HOME/workspace-automation.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Wait for X server to be ready
wait_for_xserver() {
    log "Waiting for X server..."
    local timeout=60
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if xset q &>/dev/null; then
            log "X server is ready."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    log "ERROR: X server not available after ${timeout}s"
    return 1
}

# Get window ID by pattern
get_window_id() {
    local pattern="$1"
    wmctrl -l | grep -i "$pattern" | head -n 1 | awk '{print $1}'
}

# Move window to workspace
move_to_workspace() {
    local window_id="$1"
    local workspace="$2"
    
    if [ -z "$window_id" ]; then
        log "ERROR: No window ID provided for workspace $workspace"
        return 1
    fi
    
    log "Moving window $window_id to workspace $workspace"
    wmctrl -i -r "$window_id" -t "$workspace"
    sleep 0.5
}

# Apply fullscreen to window
apply_fullscreen() {
    local window_id="$1"
    
    if [ -z "$window_id" ]; then
        log "ERROR: No window ID provided for fullscreen"
        return 1
    fi
    
    log "Applying fullscreen to window $window_id"
    wmctrl -i -r "$window_id" -b add,fullscreen
    sleep 0.5
}

# Launch Chromium in kiosk mode
launch_chromium() {
    local url="$1"
    local workspace="$2"
    local name="$3"
    
    log "Launching Chromium: $name ($url) on workspace $workspace"
    
    chromium-browser $CHROMIUM_BASE_FLAGS "$url" &
    local pid=$!
    
    sleep 5
    
    local window_count=$(wmctrl -l | grep -c "Chromium" || echo 0)
    log "Current Chromium windows: $window_count"
    
    if [ "$window_count" -gt 0 ]; then
        local window_id=$(wmctrl -l | grep "Chromium" | tail -n 1 | awk '{print $1}')
        
        if [ -n "$window_id" ]; then
            log "Window found: $window_id"
            move_to_workspace "$window_id" "$workspace"
            apply_fullscreen "$window_id"
            log "✓ Successfully configured Chromium on workspace $workspace"
            return 0
        fi
    fi
    
    log "WARNING: Failed to configure Chromium for $url"
    return 1
}

# Launch Firefox in kiosk mode
launch_firefox() {
    local url="$1"
    local workspace="$2"
    local name="$3"
    local profile_dir="$HOME/.mozilla/firefox/kiosk-ws-$workspace"
    
    log "Launching Firefox: $name ($url) on workspace $workspace"
    
    mkdir -p "$profile_dir"
    firefox $FIREFOX_BASE_FLAGS --profile "$profile_dir" "$url" &
    local pid=$!
    
    sleep 5
    
    local window_count=$(wmctrl -l | grep -c "Firefox" || echo 0)
    log "Current Firefox windows: $window_count"
    
    if [ "$window_count" -gt 0 ]; then
        local window_id=$(wmctrl -l | grep "Firefox" | tail -n 1 | awk '{print $1}')
        
        if [ -n "$window_id" ]; then
            log "Window found: $window_id"
            move_to_workspace "$window_id" "$workspace"
            apply_fullscreen "$window_id"
            log "✓ Successfully configured Firefox on workspace $workspace"
            return 0
        fi
    fi
    
    log "WARNING: Failed to configure Firefox for $url"
    return 1
}

# Launch custom application
launch_app() {
    local command="$1"
    local workspace="$2"
    local name="$3"
    
    log "Launching application: $name on workspace $workspace"
    log "Command: $command"
    
    # Launch application
    eval "$command" &
    local pid=$!
    
    # Wait for window to appear
    sleep 5
    
    # Try to find window by getting the most recent non-browser window
    local window_id=$(wmctrl -l | grep -v "Chromium\|Firefox" | tail -n 1 | awk '{print $1}')
    
    if [ -n "$window_id" ]; then
        log "Application window found: $window_id"
        move_to_workspace "$window_id" "$workspace"
        
        # Try to make fullscreen
        apply_fullscreen "$window_id"
        
        log "✓ Successfully configured application on workspace $workspace"
        return 0
    fi
    
    log "WARNING: Could not detect application window"
    return 1
}

# Main execution
main() {
    log "=========================================="
    log "Xorg Workspace Kiosk - Starting"
    log "=========================================="
    
    # Parse configuration
    parse_config
    
    # Wait for X server
    if ! wait_for_xserver; then
        log "FATAL: Cannot proceed without X server"
        exit 1
    fi
    
    # Initial delay for system stability
    log "Waiting for system stability..."
    sleep 5
    
    # Log workspace information
    log "System workspace count: $(wmctrl -d | wc -l)"
    log "Configured workspaces: ${#WORKSPACE_TYPES[@]}"
    
    # Get sorted list of workspace numbers
    workspaces=($(for ws in "${!WORKSPACE_TYPES[@]}"; do echo "$ws"; done | sort -n))
    
    # Launch applications in order
    for workspace in "${workspaces[@]}"; do
        local type="${WORKSPACE_TYPES[$workspace]}"
        local url="${WORKSPACE_URLS[$workspace]}"
        local command="${WORKSPACE_COMMANDS[$workspace]}"
        local name="${WORKSPACE_NAMES[$workspace]:-Workspace $workspace}"
        
        log "Processing workspace $workspace: $type"
        
        case "$type" in
            chromium)
                if [ -z "$url" ]; then
                    log "ERROR: No URL specified for chromium workspace $workspace"
                    continue
                fi
                launch_chromium "$url" "$workspace" "$name"
                ;;
            firefox)
                if [ -z "$url" ]; then
                    log "ERROR: No URL specified for firefox workspace $workspace"
                    continue
                fi
                launch_firefox "$url" "$workspace" "$name"
                ;;
            app)
                if [ -z "$command" ]; then
                    log "ERROR: No command specified for app workspace $workspace"
                    continue
                fi
                launch_app "$command" "$workspace" "$name"
                ;;
            *)
                log "ERROR: Unknown type '$type' for workspace $workspace"
                ;;
        esac
        
        # Delay between launches - critical for separate windows
        sleep 3
    done
    
    # Return to first configured workspace
    if [ ${#workspaces[@]} -gt 0 ]; then
        first_workspace="${workspaces[0]}"
        log "Switching to workspace $first_workspace"
        wmctrl -s "$first_workspace"
    fi
    
    log "=========================================="
    log "Workspace Automation Complete"
    log "=========================================="
    
    # Keep script running to maintain process
    log "Monitoring mode active. Press Ctrl+C to stop."
    
    # Monitor mode - check if windows still exist every 60 seconds
    local expected_count=${#WORKSPACE_TYPES[@]}
    while true; do
        sleep 60
        window_count=$(wmctrl -l | grep -E "Chromium|Firefox" | wc -l)
        log "Health check: $window_count/$expected_count windows active"
        
        if [ "$window_count" -lt "$expected_count" ]; then
            log "WARNING: Window count below expected. Some windows may have closed."
        fi
    done
}

# Trap signals for clean shutdown
trap 'log "Received termination signal. Exiting..."; exit 0' SIGTERM SIGINT

# Run main
main
