# Structured logging utilities for efrit-nu
# Provides consistent logging across all components

export def setup-logging [config?: record] {
    let log_config = ($config | default {
        level: "info",
        format: "json",
        output: "data/logs/efrit-nu.log",
        max_size: "100MB",
        max_files: 10
    })
    
    # Ensure log directory exists
    let log_dir = ($log_config.output | path dirname)
    if not ($log_dir | path exists) {
        mkdir $log_dir
    }
    
    # Set global logging configuration
    load-env { EFRIT_LOG_CONFIG: $log_config }
}

export def log [
    level: string    # debug, info, warn, error
    message: string  # Log message
    --component (-c): string = "core"  # Component name
    --data (-d): record = {}           # Additional structured data
] {
    let log_config = (if "EFRIT_LOG_CONFIG" in $env { $env.EFRIT_LOG_CONFIG } else { {
        level: "info",
        format: "json", 
        output: "data/logs/efrit-nu.log"
    } })
    
    let level_priority = match $level {
        "debug" => 0,
        "info" => 1, 
        "warn" => 2,
        "error" => 3,
        _ => 1
    }
    
    let config_priority = match $log_config.level {
        "debug" => 0,
        "info" => 1,
        "warn" => 2, 
        "error" => 3,
        _ => 1
    }
    
    # Only log if level meets threshold
    if $level_priority < $config_priority {
        return
    }
    
    let log_entry = {
        timestamp: (date now | format date "%Y-%m-%dT%H:%M:%S%.3fZ"),
        level: $level,
        component: $component,
        message: $message,
        data: $data,
        pid: (if "EFRIT_PID" in $env { $env.EFRIT_PID } else { null }),
        session_id: (if "EFRIT_SESSION_ID" in $env { $env.EFRIT_SESSION_ID } else { null })
    }
    
    # Format and write log entry
    match $log_config.format {
        "json" => {
            ($log_entry | to json --raw) + "\n" | save --append $log_config.output
        },
        "text" => {
            let formatted = $"[($log_entry.timestamp)] [($level | str upcase)] [($component)] ($message)"
            $formatted + "\n" | save --append $log_config.output
        },
        _ => {
            ($log_entry | to json --raw) + "\n" | save --append $log_config.output
        }
    }
    
    # Also output to stderr for immediate visibility
    if $level in ["warn", "error"] {
        $log_entry | to json --raw | print --stderr
    }
}

export def log-debug [message: string, --component (-c): string = "core", --data (-d): record = {}] {
    log "debug" $message --component $component --data $data
}

export def log-info [message: string, --component (-c): string = "core", --data (-d): record = {}] {
    log "info" $message --component $component --data $data
}

export def log-warn [message: string, --component (-c): string = "core", --data (-d): record = {}] {
    log "warn" $message --component $component --data $data
}

export def log-error [message: string, --component (-c): string = "core", --data (-d): record = {}] {
    log "error" $message --component $component --data $data
}

export def log-request [request_id: string, action: string, --data (-d): record = {}] {
    let request_data = ($data | upsert request_id $request_id | upsert action $action)
    log "info" $"Request ($action): ($request_id)" --component "queue" --data $request_data
}

export def log-performance [
    operation: string
    duration_ms: int
    --data (-d): record = {}
] {
    let perf_data = ($data | upsert operation $operation | upsert duration_ms $duration_ms)
    log "info" $"Performance: ($operation) completed in ($duration_ms)ms" --component "performance" --data $perf_data
}

export def log-provider [
    provider: string
    action: string
    --success (-s) = true
    --data (-d): record = {}
] {
    let provider_data = ($data | upsert provider $provider | upsert action $action | upsert success $success)
    let level = if $success { "info" } else { "error" }
    let status = if $success { "succeeded" } else { "failed" }
    
    log $level $"Provider ($provider) ($action) ($status)" --component "provider" --data $provider_data
}

export def rotate-logs [] {
    let log_config = (if "EFRIT_LOG_CONFIG" in $env { $env.EFRIT_LOG_CONFIG } else { {
        output: "data/logs/efrit-nu.log",
        max_size: "100MB",
        max_files: 10
    } })
    
    let log_file = $log_config.output
    
    if not ($log_file | path exists) {
        return
    }
    
    let file_size = (ls $log_file | get size | first)
    let max_size_bytes = (
        $log_config.max_size 
        | str replace "MB" "" 
        | into int 
        | $in * 1024 * 1024
    )
    
    if $file_size > $max_size_bytes {
        let timestamp = (date now | format date "%Y%m%d_%H%M%S")
        let archived_name = ($log_file + "." + $timestamp)
        
        # Move current log to archived name
        mv $log_file $archived_name
        
        # Clean up old log files
        let log_dir = ($log_file | path dirname)
        let base_name = ($log_file | path basename)
        
        let old_logs = (
            ls ($log_dir + "/" + $base_name + ".*")
            | sort-by modified
            | reverse
            | skip ($log_config.max_files | into int)
        )
        
        for log in $old_logs {
            rm $log.name
        }
        
        log-info $"Log rotated: ($archived_name)" --component "logging"
    }
}

export def get-recent-logs [
    --lines (-n): int = 100
    --level (-l): string
    --component (-c): string
    --since (-s): string  # e.g., "1h", "30m", "2d"
] {
    let log_config = (if "EFRIT_LOG_CONFIG" in $env { $env.EFRIT_LOG_CONFIG } else { {
        output: "data/logs/efrit-nu.log",
        format: "json"
    } })
    
    if not ($log_config.output | path exists) {
        return []
    }
    
    let raw_logs = (
        open $log_config.output
        | lines
        | last $lines
        | where ($it | str trim) != ""
    )
    
    let parsed_logs = if ($log_config.format == "json") {
        $raw_logs | each { |line| $line | from json }
    } else {
        $raw_logs | each { |line| { message: $line, timestamp: null, level: "info", component: "unknown" } }
    }
    
    let filtered_logs = $parsed_logs
        | (if $level != null { where level == $level } else { $in })
        | (if $component != null { where component == $component } else { $in })
    
    # TODO: Implement time-based filtering for --since
    
    $filtered_logs
}

export def clear-logs [] {
    let log_config = (if "EFRIT_LOG_CONFIG" in $env { $env.EFRIT_LOG_CONFIG } else { {
        output: "data/logs/efrit-nu.log"
    } })
    
    if ($log_config.output | path exists) {
        "" | save $log_config.output
        log-info "Logs cleared" --component "logging"
    }
}
