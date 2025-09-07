# Unit tests for logging system
# Tests the logging.nu module functionality

use ../../scripts/utils/logging.nu *

# Test logging setup
export def test_logging_setup [] {
    let test_log_config = {
        level: "debug",
        format: "json",
        output: "tests/tmp/test.log",
        max_size: "10MB",
        max_files: 5
    }
    
    # Ensure test directory exists
    mkdir "tests/tmp"
    
    setup-logging $test_log_config
    
    # Check if environment variable is set
    if not ("EFRIT_LOG_CONFIG" in $env) {
        error make { msg: "Logging configuration not set in environment" }
    }
    
    print "✅ Logging setup test passed"
    true
}

# Test basic logging functionality
export def test_basic_logging [] {
    let test_log_config = {
        level: "debug",
        format: "json", 
        output: "tests/tmp/basic_test.log"
    }
    
    setup-logging $test_log_config
    
    log-debug "Test debug message"
    log-info "Test info message" 
    log-warn "Test warning message"
    log-error "Test error message"
    
    # Check if log file exists and has content
    if not ("tests/tmp/basic_test.log" | path exists) {
        error make { msg: "Log file was not created" }
    }
    
    let log_content = (open "tests/tmp/basic_test.log" | lines)
    
    if ($log_content | length) < 4 {
        error make { msg: $"Expected 4 log entries, found ($log_content | length)" }
    }
    
    # Test if logs are valid JSON
    for line in $log_content {
        if ($line | str trim) != "" {
            try {
                $line | from json | ignore
            } catch {
                error make { msg: $"Invalid JSON in log line: ($line)" }
            }
        }
    }
    
    print "✅ Basic logging test passed"
    true
}

# Test log levels filtering
export def test_log_levels [] {
    let test_log_config = {
        level: "warn",
        format: "json",
        output: "tests/tmp/levels_test.log"
    }
    
    setup-logging $test_log_config
    
    # Remove any existing log file
    if ("tests/tmp/levels_test.log" | path exists) {
        rm "tests/tmp/levels_test.log"
    }
    
    log-debug "Debug message (should not appear)"
    log-info "Info message (should not appear)"
    log-warn "Warning message (should appear)"
    log-error "Error message (should appear)"
    
    if not ("tests/tmp/levels_test.log" | path exists) {
        error make { msg: "Log file was not created" }
    }
    
    let log_lines = (open "tests/tmp/levels_test.log" | lines | where ($it | str trim) != "")
    
    # Should only have warn and error messages (2 lines)
    if ($log_lines | length) != 2 {
        error make { msg: $"Expected 2 log entries (warn+error), found ($log_lines | length)" }
    }
    
    # Parse and check log levels
    let log_entries = ($log_lines | each { |line| $line | from json })
    let levels = ($log_entries | get level)
    
    if not ("warn" in $levels and "error" in $levels) {
        error make { msg: "Expected warn and error levels in filtered logs" }
    }
    
    print "✅ Log levels filtering test passed"  
    true
}

# Test structured logging with data
export def test_structured_logging [] {
    let test_log_config = {
        level: "info",
        format: "json",
        output: "tests/tmp/structured_test.log"
    }
    
    setup-logging $test_log_config
    
    if ("tests/tmp/structured_test.log" | path exists) {
        rm "tests/tmp/structured_test.log"
    }
    
    let test_data = { user_id: 123, action: "test", count: 42 }
    
    log-info "Structured test message" --component "test" --data $test_data
    
    let log_content = (open "tests/tmp/structured_test.log" | lines | where ($it | str trim) != "" | first)
    let log_entry = ($log_content | from json)
    
    # Check required fields
    let required_fields = ["timestamp", "level", "component", "message", "data"]
    for field in $required_fields {
        if ($log_entry | get $field -o) == null {
            error make { msg: $"Missing required field in log entry: ($field)" }
        }
    }
    
    # Check data integrity
    if $log_entry.data != $test_data {
        error make { msg: "Structured data was not preserved correctly" }
    }
    
    print "✅ Structured logging test passed"
    true
}

# Test performance logging
export def test_performance_logging [] {
    let test_log_config = {
        level: "info",
        format: "json", 
        output: "tests/tmp/performance_test.log"
    }
    
    setup-logging $test_log_config
    
    if ("tests/tmp/performance_test.log" | path exists) {
        rm "tests/tmp/performance_test.log"
    }
    
    log-performance "test_operation" 150 --data { status: "success" }
    
    let log_content = (open "tests/tmp/performance_test.log" | lines | where ($it | str trim) != "" | first)
    let log_entry = ($log_content | from json)
    
    # Check performance-specific fields
    if $log_entry.component != "performance" {
        error make { msg: "Performance log should have 'performance' component" }
    }
    
    if $log_entry.data.operation != "test_operation" {
        error make { msg: "Performance operation name not preserved" }
    }
    
    if $log_entry.data.duration_ms != 150 {
        error make { msg: "Performance duration not preserved" }
    }
    
    print "✅ Performance logging test passed"
    true
}

# Test provider logging  
export def test_provider_logging [] {
    let test_log_config = {
        level: "info",
        format: "json",
        output: "tests/tmp/provider_test.log"  
    }
    
    setup-logging $test_log_config
    
    if ("tests/tmp/provider_test.log" | path exists) {
        rm "tests/tmp/provider_test.log"
    }
    
    # Test successful provider operation
    log-provider "anthropic" "request" --success true --data { model: "claude-3" }
    
    # Test failed provider operation  
    log-provider "ollama" "connection" --success false --data { error: "timeout" }
    
    let log_lines = (open "tests/tmp/provider_test.log" | lines | where ($it | str trim) != "")
    
    if ($log_lines | length) != 2 {
        error make { msg: $"Expected 2 provider log entries, found ($log_lines | length)" }
    }
    
    let entries = ($log_lines | each { |line| $line | from json })
    
    # Check first entry (success)
    let success_entry = ($entries | first)
    if $success_entry.level != "info" or $success_entry.data.success != true {
        error make { msg: "Success provider log entry incorrect" }
    }
    
    # Check second entry (failure)
    let failure_entry = ($entries | last)
    if $failure_entry.level != "error" or $failure_entry.data.success != false {
        error make { msg: "Failure provider log entry incorrect" }
    }
    
    print "✅ Provider logging test passed"
    true
}

# Clean up test files
export def cleanup_test_logs [] {
    if ("tests/tmp" | path exists) {
        rm -rf "tests/tmp"
    }
    
    print "🧹 Test log files cleaned up"
}

# Run all logging tests
export def run_logging_tests [] {
    print "🧪 Running logging tests..."
    
    # Ensure clean state
    cleanup_test_logs
    
    mut passed = 0
    mut total = 6
    
    try {
        test_logging_setup
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_logging_setup failed: ($err.msg)"
    }
    
    try {
        test_basic_logging
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_basic_logging failed: ($err.msg)"
    }
    
    try {
        test_log_levels
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_log_levels failed: ($err.msg)"
    }
    
    try {
        test_structured_logging
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_structured_logging failed: ($err.msg)"
    }
    
    try {
        test_performance_logging
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_performance_logging failed: ($err.msg)"
    }
    
    try {
        test_provider_logging
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_provider_logging failed: ($err.msg)"
    }
    
    # Clean up after tests
    cleanup_test_logs
    
    print $"📊 Logging tests: ($passed)/($total) passed"
    
    if $passed == $total {
        print "🎉 All logging tests passed!"
        true
    } else {
        error make { msg: $"($total - $passed) logging tests failed" }
    }
}
