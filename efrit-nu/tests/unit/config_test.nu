# Unit tests for configuration management
# Tests the config.nu module functionality

use ../../scripts/utils/config.nu *

# Test configuration loading
export def test_load_config [] {
    let config = (load-config)
    
    # Should contain all required sections
    let required_sections = ["system", "queues", "providers", "tools", "performance", "security"]
    
    for section in $required_sections {
        if ($config | get $section -o) == null {
            error make { msg: $"Missing required config section: ($section)" }
        }
    }
    
    print "✅ Configuration loading test passed"
    true
}

# Test configuration validation
export def test_validate_config [] {
    let valid_config = {
        system: { 
            log_level: "info", 
            max_concurrent_requests: 10, 
            request_timeout: 30, 
            session_ttl: 3600, 
            pid_file: "test.pid" 
        },
        queues: { 
            base_path: "test/queues", 
            cleanup_interval: 300, 
            max_file_size: 1048576, 
            batch_size: 100, 
            poll_interval: 1, 
            max_processing_time: 300 
        },
        providers: { 
            default: "test", 
            timeout: 30, 
            retry_attempts: 3, 
            rate_limit_per_minute: 60, 
            config_file: "test.toml" 
        },
        tools: { 
            container_memory_limit: "512m", 
            container_cpu_limit: "1.0", 
            execution_timeout: 60, 
            network_isolation: true, 
            docker_image: "test:latest", 
            temp_dir: "/tmp/test" 
        },
        performance: { 
            cache_ttl: 300, 
            compression_level: "smart", 
            enable_metrics: true, 
            metrics_retention_days: 30, 
            max_context_size: 100000, 
            work_log_max_entries: 50 
        },
        security: { 
            enable_audit_log: true, 
            max_request_size: 10485760, 
            allowed_file_extensions: [".txt"], 
            forbidden_paths: ["/etc"], 
            container_user: "test" 
        }
    }
    
    let result = (validate-config $valid_config)
    
    if $result != $valid_config {
        error make { msg: "Valid configuration failed validation" }
    }
    
    print "✅ Configuration validation test passed"
    true
}

# Test configuration validation with invalid data
export def test_validate_config_invalid [] {
    let invalid_config = {
        system: { log_level: "info" }
        # Missing required sections
    }
    
    let test_passed = try {
        validate-config $invalid_config
        false # Should have failed
    } catch { 
        true # Expected to fail
    }
    
    if not $test_passed {
        error make { msg: "Invalid configuration validation should have failed" }
    }
    
    print "✅ Invalid configuration validation test passed"
    true
}

# Test environment configuration
export def test_env_config [] {
    let env_config = (get-env-config)
    
    # Should contain expected keys
    let expected_keys = ["log_level", "max_concurrent_requests", "providers_config", "data_directory", "docker_network"]
    
    for key in $expected_keys {
        if ($env_config | get $key -o) == null {
            error make { msg: $"Missing expected env config key: ($key)" }
        }
    }
    
    print "✅ Environment configuration test passed"
    true
}

# Test provider listing
export def test_list_providers [] {
    # This test assumes the providers.toml file exists
    if ("config/providers.toml" | path exists) {
        let providers = (list-providers)
        
        if ($providers | length) == 0 {
            error make { msg: "No providers found in configuration" }
        }
        
        # Check if expected providers exist
        let expected_providers = ["anthropic", "ollama", "openai"]
        for provider in $expected_providers {
            if not ($provider in $providers) {
                error make { msg: $"Expected provider ($provider) not found" }
            }
        }
        
        print "✅ Provider listing test passed"
    } else {
        print "⚠️  Providers configuration file not found, skipping test"
    }
    
    true
}

# Run all configuration tests
export def run_config_tests [] {
    print "🧪 Running configuration tests..."
    
    mut passed = 0
    mut total = 5
    
    try {
        test_load_config
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_load_config failed: ($err.msg)"
    }
    
    try {
        test_validate_config
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_validate_config failed: ($err.msg)"
    }
    
    try {
        test_validate_config_invalid
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_validate_config_invalid failed: ($err.msg)"
    }
    
    try {
        test_env_config
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_env_config failed: ($err.msg)"
    }
    
    try {
        test_list_providers
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_list_providers failed: ($err.msg)"
    }
    
    print $"📊 Configuration tests: ($passed)/($total) passed"
    
    if $passed == $total {
        print "🎉 All configuration tests passed!"
        true
    } else {
        error make { msg: $"($total - $passed) configuration tests failed" }
    }
}
