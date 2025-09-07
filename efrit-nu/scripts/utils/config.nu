# Configuration management utilities for efrit-nu
# Handles loading and merging configuration from multiple sources

export def load-config [config_file?: string] {
    let default_config = {
        system: {
            log_level: "info",
            max_concurrent_requests: 10,
            request_timeout: 30,
            session_ttl: 3600
        },
        queues: {
            base_path: "data/queues",
            cleanup_interval: 300,
            max_file_size: 1048576,
            batch_size: 100
        },
        providers: {
            default: "anthropic",
            timeout: 30,
            retry_attempts: 3,
            rate_limit_per_minute: 60
        },
        tools: {
            container_memory_limit: "512m",
            container_cpu_limit: "1.0",
            execution_timeout: 60,
            network_isolation: true
        },
        performance: {
            cache_ttl: 300,
            compression_level: "smart",
            enable_metrics: true,
            metrics_retention_days: 30
        }
    }
    
    let config_path = ($config_file | default "config/system.toml")
    
    if ($config_path | path exists) {
        let file_config = (open $config_path)
        $default_config | merge $file_config
    } else {
        $default_config
    }
}

export def get-env-config [] {
    {
        log_level: ($env.EFRIT_LOG_LEVEL? | default "info"),
        max_concurrent_requests: ($env.EFRIT_MAX_CONCURRENT? | default 10 | into int),
        providers_config: ($env.EFRIT_PROVIDERS_CONFIG? | default "config/providers.toml"),
        data_directory: ($env.EFRIT_DATA_DIR? | default "data"),
        docker_network: ($env.EFRIT_DOCKER_NETWORK? | default "none")
    }
}

export def validate-config [config: record] {
    let required_keys = [
        "system", "queues", "providers", "tools", "performance"
    ]
    
    let missing_keys = (
        $required_keys 
        | where {|key| ($config | get $key -o) == null}
    )
    
    if ($missing_keys | length) > 0 {
        error make {
            msg: $"Missing required configuration keys: ($missing_keys | str join ', ')"
        }
    }
    
    # Validate specific constraints
    if ($config.system.max_concurrent_requests < 1) {
        error make {
            msg: "max_concurrent_requests must be greater than 0"
        }
    }
    
    if ($config.system.request_timeout < 1) {
        error make {
            msg: "request_timeout must be greater than 0"
        }
    }
    
    $config
}

export def save-config [config: record, config_file?: string] {
    let config_path = ($config_file | default "config/system.toml")
    let config_dir = ($config_path | path dirname)
    
    if not ($config_dir | path exists) {
        mkdir $config_dir
    }
    
    $config | to toml | save $config_path
}

export def get-provider-config [provider: string] {
    let providers_config = (load-config | get providers)
    let providers_file = ($providers_config.config_file? | default "config/providers.toml")
    
    if not ($providers_file | path exists) {
        error make {
            msg: $"Providers configuration file not found: ($providers_file)"
        }
    }
    
    let all_providers = (open $providers_file)
    
    if ($provider in $all_providers) {
        $all_providers | get $provider
    } else {
        error make {
            msg: $"Provider '($provider)' not found in configuration"
        }
    }
}

export def list-providers [] {
    let providers_file = "config/providers.toml"
    
    if ($providers_file | path exists) {
        let providers = (open $providers_file)
        $providers | columns
    } else {
        []
    }
}

export def update-provider-config [provider: string, config: record] {
    let providers_file = "config/providers.toml"
    let providers = if ($providers_file | path exists) {
        open $providers_file
    } else {
        {}
    }
    
    let updated_providers = ($providers | upsert $provider $config)
    $updated_providers | to toml | save $providers_file
}
