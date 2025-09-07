# Queue management system for efrit-nu
# Handles request/response queues with file-based storage

use ../utils/config.nu *
use ../utils/logging.nu *

# Helper function to safely list files with a pattern
def safe-ls [pattern: string] {
    try {
        glob $pattern | each { |file| ls $file } | flatten
    } catch {
        []
    }
}

export def init-queues [config?: record] {
    let queue_config = (if $config != null { $config.queues } else { load-config | get queues })
    
    log-info "Initializing queue system" --component "queue" --data $queue_config
    
    let base_path = $queue_config.base_path
    let queue_dirs = ["requests", "processing", "responses", "archive"]
    
    for dir in $queue_dirs {
        let full_path = ($base_path | path join $dir)
        if not ($full_path | path exists) {
            mkdir $full_path
            log-debug $"Created queue directory: ($full_path)" --component "queue"
        }
    }
    
    # Set queue configuration in environment
    $env.EFRIT_QUEUE_CONFIG = $queue_config
    
    log-info "Queue system initialized successfully" --component "queue"
}

export def generate-request-id [] {
    let timestamp = (date now | format date "%Y%m%d_%H%M%S")
    let random = (random chars --length 8)
    $"efrit_($timestamp)_($random)"
}

export def validate-request [request: record] {
    let required_fields = ["id", "type", "content"]
    let valid_types = ["command", "chat", "eval"]
    
    # Check required fields
    for field in $required_fields {
        if ($request | get $field -o) == null {
            return {
                valid: false,
                error: $"Missing required field: ($field)"
            }
        }
    }
    
    # Validate request type
    if not ($request.type in $valid_types) {
        return {
            valid: false,
            error: $"Invalid request type '($request.type)'. Must be one of: ($valid_types | str join ', ')"
        }
    }
    
    # Validate content is not empty
    if ($request.content | str trim | is-empty) {
        return {
            valid: false,
            error: "Request content cannot be empty"
        }
    }
    
    # Validate optional fields
    let options = ($request | get options -o | default {})
    if ($options | describe) != "record" {
        return {
            valid: false,
            error: "Options field must be a record"
        }
    }
    
    {
        valid: true,
        error: null
    }
}

export def enqueue-request [request: record] {
    let validation = (validate-request $request)
    
    if not $validation.valid {
        log-error $"Request validation failed: ($validation.error)" --component "queue"
        error make { msg: $validation.error }
    }
    
    let queue_config = (if "EFRIT_QUEUE_CONFIG" in $env { $env.EFRIT_QUEUE_CONFIG } else { load-config | get queues })
    let request_file = ($queue_config.base_path | path join "requests" | path join ($request.id + ".json"))
    
    # Add metadata
    let enriched_request = ($request | upsert metadata {
        enqueued_at: (date now | format date "%Y-%m-%dT%H:%M:%S%.3fZ"),
        source: "efrit-nu",
        version: "1.0"
    })
    
    # Write to requests directory
    $enriched_request | to json | save $request_file
    
    log-request $request.id "enqueued" --data {
        type: $request.type,
        file: $request_file
    }
    
    $request.id
}

export def dequeue-request [] {
    let queue_config = (if "EFRIT_QUEUE_CONFIG" in $env { $env.EFRIT_QUEUE_CONFIG } else { load-config | get queues })
    let requests_dir = ($queue_config.base_path | path join "requests")
    let processing_dir = ($queue_config.base_path | path join "processing")
    
    # Get oldest request file
    let request_files = (
        safe-ls ($requests_dir | path join "*.json")
        | where type == "file"
        | sort-by modified
    )
    
    if ($request_files | is-empty) {
        return null
    }
    
    let oldest_file = ($request_files | first)
    let request_id = ($oldest_file.name | path basename | str replace ".json" "")
    let processing_file = ($processing_dir | path join ($request_id + ".json"))
    
    # Move to processing directory
    mv $oldest_file.name $processing_file
    
    # Load and return request
    let request = (open $processing_file)
    
    log-request $request_id "dequeued" --data {
        type: $request.type,
        processing_file: $processing_file
    }
    
    {
        request: $request,
        processing_file: $processing_file
    }
}

export def create-response [request_id: string, status: string, result?: any, error?: string] {
    let response = {
        id: $request_id,
        timestamp: (date now | format date "%Y-%m-%dT%H:%M:%S%.3fZ"),
        status: $status,
        result: $result,
        error: $error
    }
    
    $response
}

export def enqueue-response [response: record] {
    let queue_config = (if "EFRIT_QUEUE_CONFIG" in $env { $env.EFRIT_QUEUE_CONFIG } else { load-config | get queues })
    let response_file = ($queue_config.base_path | path join "responses" | path join ($response.id + ".json"))
    
    $response | to json | save $response_file
    
    log-request $response.id "response_enqueued" --data {
        status: $response.status,
        file: $response_file
    }
    
    $response.id
}

export def complete-request [processing_file: string, response: record] {
    let queue_config = (if "EFRIT_QUEUE_CONFIG" in $env { $env.EFRIT_QUEUE_CONFIG } else { load-config | get queues })
    let archive_dir = ($queue_config.base_path | path join "archive")
    let request_id = $response.id
    
    # Move processing file to archive
    let archive_file = ($archive_dir | path join ($request_id + "_request.json"))
    mv $processing_file $archive_file
    
    # Enqueue response
    enqueue-response $response
    
    log-request $request_id "completed" --data {
        status: $response.status,
        archived: $archive_file
    }
}

export def get-queue-status [] {
    let queue_config = (if "EFRIT_QUEUE_CONFIG" in $env { $env.EFRIT_QUEUE_CONFIG } else { load-config | get queues })
    let base_path = $queue_config.base_path
    
    let requests_count = (safe-ls ($base_path | path join "requests" | path join "*.json") | length)
    let processing_count = (safe-ls ($base_path | path join "processing" | path join "*.json") | length)
    let responses_count = (safe-ls ($base_path | path join "responses" | path join "*.json") | length)
    let archive_count = (safe-ls ($base_path | path join "archive" | path join "*.json") | length)
    
    {
        requests_pending: $requests_count,
        requests_processing: $processing_count,
        responses_available: $responses_count,
        requests_archived: $archive_count,
        total_processed: $archive_count
    }
}

export def cleanup-queues [older_than_hours?: int] {
    let queue_config = (if "EFRIT_QUEUE_CONFIG" in $env { $env.EFRIT_QUEUE_CONFIG } else { load-config | get queues })
    let hours_threshold = ($older_than_hours | default 24)
    let cutoff_time = ((date now) - (($hours_threshold * 60 * 60 * 1000 * 1000 * 1000) | into duration))
    
    let base_path = $queue_config.base_path
    let cleanup_dirs = ["responses", "archive"]
    
    mut cleanup_count = 0
    
    for dir in $cleanup_dirs {
        let full_dir = ($base_path | path join $dir)
        let old_files = (
            safe-ls ($full_dir | path join "*.json")
            | where modified < $cutoff_time
        )
        
        for file in $old_files {
            rm $file.name
            $cleanup_count = ($cleanup_count + 1)
        }
    }
    
    log-info $"Cleaned up ($cleanup_count) old queue files" --component "queue" --data {
        older_than_hours: $hours_threshold,
        files_removed: $cleanup_count
    }
    
    $cleanup_count
}

export def start-queue-processor [] {
    log-info "Starting queue processor" --component "queue"
    
    let config = (load-config)
    init-queues $config
    
    # Main processing loop
    loop {
        let request_data = (dequeue-request)
        
        if $request_data != null {
            let request = $request_data.request
            let processing_file = $request_data.processing_file
            
            log-info $"Processing request: ($request.id)" --component "queue" --data {
                type: $request.type,
                content_length: ($request.content | str length)
            }
            
            # Process the request (this will be expanded with actual processing logic)
            let response = (process-request $request)
            
            # Complete the request
            complete-request $processing_file $response
        } else {
            # No requests available, sleep briefly
            sleep 1sec
        }
    }
}

# Placeholder for request processing - will be implemented in later phases
def process-request [request: record] {
    log-warn "Request processing not yet implemented" --component "queue"
    
    create-response $request.id "error" null "Request processing not yet implemented"
}

export def stop-queue-processor [] {
    log-info "Queue processor stop requested" --component "queue"
    # This would set a flag to stop the main loop
    # For now, just log the request
}
