# Main test runner for efrit-nu
# Runs all unit and integration tests

use unit/config_test.nu *
use unit/logging_test.nu *
use unit/queue_test.nu *
use ../scripts/utils/config.nu *
use ../scripts/utils/logging.nu *
use ../scripts/core/queue.nu *

# Run all unit tests
export def run_all_unit_tests [] {
    print "🚀 Starting efrit-nu unit tests..."
    print ""
    
    let results = [
        (try { run_config_tests; "config_pass" } catch { "config_fail" }),
        (try { run_logging_tests; "logging_pass" } catch { "logging_fail" }),
        (try { run_queue_tests; "queue_pass" } catch { "queue_fail" })
    ]
    
    let total_passed = ($results | where ($it | str ends-with "_pass") | length)
    let total_failed = ($results | where ($it | str ends-with "_fail") | length)
    
    # Print individual results
    if "config_fail" in $results {
        print "❌ Configuration tests failed"
    }
    
    if "logging_fail" in $results {
        print "❌ Logging tests failed" 
    }
    
    if "queue_fail" in $results {
        print "❌ Queue tests failed"
    }
    
    print ""
    
    # Print summary
    print "📈 Test Summary:"
    print $"  ✅ Test suites passed: ($total_passed)"
    print $"  ❌ Test suites failed: ($total_failed)"
    print $"  📊 Success rate: (($total_passed * 100) / ($total_passed + $total_failed))%"
    
    if $total_failed == 0 {
        print ""
        print "🎉 All tests passed! efrit-nu is working correctly."
        true
    } else {
        print ""
        print "⚠️  Some tests failed. Please check the output above."
        false
    }
}

# Performance test - measure basic operations
export def run_performance_tests [] {
    print "⚡ Running performance tests..."
    
    # Test configuration loading performance
    let config_start = (date now)
    for i in 1..10 {
        load-config | ignore
    }
    let config_duration = ((date now) - $config_start)
    
    print $"⏱️  Config loading 10x: ($config_duration)"
    
    # Test queue operations performance
    let queue_config = {
        queues: {
            base_path: "tests/tmp/perf_queues",
            cleanup_interval: 300,
            max_file_size: 1048576,
            batch_size: 100,
            poll_interval: 1,
            max_processing_time: 300
        }
    }
    
    if ("tests/tmp" | path exists) {
        rm -rf "tests/tmp"
    }
    
    init-queues $queue_config
    
    let queue_start = (date now)
    for i in 1..100 {
        let request = {
            id: $"perf_test_($i)",
            type: "eval",
            content: $"test ($i)"
        }
        enqueue-request $request | ignore
    }
    let queue_duration = ((date now) - $queue_start)
    
    print $"⏱️  Queue operations 100 requests: ($queue_duration)"
    
    # Clean up
    rm -rf "tests/tmp"
    
    print "✅ Performance tests completed"
}

# System integration test
export def run_integration_test [] {
    print "🔧 Running integration test..."
    
    # Test full system startup and basic operations
    source ../scripts/utils/config.nu
    source ../scripts/utils/logging.nu
    source ../scripts/core/queue.nu
    
    # Load configuration
    let config = (load-config)
    print "✅ Configuration loaded"
    
    # Setup logging
    let log_config = {
        level: "info",
        format: "json",
        output: "tests/tmp/integration.log"
    }
    
    if not ("tests/tmp" | path exists) {
        mkdir "tests/tmp"
    }
    
    setup-logging $log_config
    log-info "Integration test started"
    print "✅ Logging initialized"
    
    # Initialize queues
    let queue_config = {
        queues: {
            base_path: "tests/tmp/integration_queues",
            cleanup_interval: 300,
            max_file_size: 1048576,
            batch_size: 100,
            poll_interval: 1,
            max_processing_time: 300
        }
    }
    
    init-queues $queue_config
    print "✅ Queues initialized"
    
    # Test complete request flow
    let request = {
        id: "integration_test_001",
        type: "eval",
        content: "2 + 2"
    }
    
    # Enqueue request
    enqueue-request $request | ignore
    log-info "Request enqueued" --data { request_id: $request.id }
    
    # Check queue status
    let status = (get-queue-status)
    
    if $status.requests_pending != 1 {
        error make { msg: "Integration test: Expected 1 pending request" }
    }
    
    # Dequeue and process
    let dequeued = (dequeue-request)
    
    if $dequeued == null {
        error make { msg: "Integration test: Failed to dequeue request" }
    }
    
    # Create response and complete
    let response = (create-response $request.id "success" "4")
    complete-request $dequeued.processing_file $response
    log-info "Request completed" --data { request_id: $request.id, result: "4" }
    
    # Verify final state
    let final_status = (get-queue-status)
    
    if $final_status.responses_available != 1 {
        error make { msg: "Integration test: Expected 1 available response" }
    }
    
    print "✅ Request flow completed"
    
    # Clean up
    rm -rf "tests/tmp"
    
    print "🎉 Integration test passed!"
}

# Main test runner
export def main [] {
    print "🧪 efrit-nu Test Suite"
    print "====================="
    print ""
    
    let start_time = (date now)
    
    # Run all tests
    let unit_tests_passed = (run_all_unit_tests)
    print ""
    
    run_performance_tests
    print ""
    
    run_integration_test
    print ""
    
    let total_duration = ((date now) - $start_time)
    
    print $"⏱️  Total test time: ($total_duration)"
    
    if $unit_tests_passed {
        print "🚀 All tests completed successfully!"
        exit 0
    } else {
        print "💥 Some tests failed!"
        exit 1
    }
}
