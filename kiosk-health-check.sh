#!/bin/bash

# Kiosk Health Check Script
# Monitors workspace automation and restarts if windows are missing

LOG_FILE="$HOME/kiosk-health.log"
EXPECTED_WINDOWS=5
MIN_UPTIME=300  # Don't restart if system just started (5 minutes)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Check system uptime to avoid false positives on boot
get_uptime_seconds() {
    awk '{print int($1)}' /proc/uptime
}

# Count active kiosk windows
count_windows() {
    wmctrl -l 2>/dev/null | grep -E "Chromium|KlipperScreen" | wc -l
}

# Check if service is running
is_service_running() {
    systemctl --user is-active workspace-automation.service >/dev/null 2>&1
}

# Main health check
main() {
    # Check if X server is available
    if ! xset q &>/dev/null; then
        log "ERROR: X server not available. Cannot perform health check."
        exit 1
    fi
    
    # Get system uptime
    uptime_sec=$(get_uptime_seconds)
    
    if [ "$uptime_sec" -lt "$MIN_UPTIME" ]; then
        log "INFO: System recently booted (uptime: ${uptime_sec}s). Skipping health check."
        exit 0
    fi
    
    # Count windows
    window_count=$(count_windows)
    
    log "Health check: Found $window_count/$EXPECTED_WINDOWS windows"
    
    # If window count is below expected and service is supposed to be running
    if [ "$window_count" -lt "$EXPECTED_WINDOWS" ]; then
        if is_service_running; then
            log "WARNING: Window count below expected. Service is running but windows missing."
            log "ACTION: Restarting workspace-automation.service"
            
            systemctl --user restart workspace-automation.service
            
            if [ $? -eq 0 ]; then
                log "SUCCESS: Service restarted successfully"
            else
                log "ERROR: Failed to restart service"
            fi
        else
            log "WARNING: Window count below expected AND service is not running."
            log "ACTION: Starting workspace-automation.service"
            
            systemctl --user start workspace-automation.service
            
            if [ $? -eq 0 ]; then
                log "SUCCESS: Service started successfully"
            else
                log "ERROR: Failed to start service"
            fi
        fi
    elif [ "$window_count" -eq "$EXPECTED_WINDOWS" ]; then
        log "OK: All windows present"
    else
        log "INFO: More windows than expected ($window_count > $EXPECTED_WINDOWS). This is fine."
    fi
}

# Run health check
main
