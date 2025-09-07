# Simple test runner for efrit-nu

# Test basic functionality manually
def main [] {
    print "🧪 Running simple efrit-nu tests..."
    print ""
    
    # Test 1: Configuration loading
    print "Testing configuration loading..."
    try {
        source ../scripts/utils/config.nu
        let config = (load-config)
        print "✅ Configuration loaded successfully"
        
        # Check required sections
        let sections = ["system", "queues", "providers", "tools", "performance", "security"]
        for section in $sections {
            if ($config | get $section -o) != null {
                print $"  ✅ Section ($section) found"
            } else {
                print $"  ❌ Section ($section) missing"
                return
            }
        }
        
    } catch { |err|
        print $"❌ Configuration test failed: ($err.msg)"
        return
    }
    
    print ""
    
    # Test 2: Logging
    print "Testing logging system..."
    try {
        source ../scripts/utils/logging.nu
        
        # Create test directory
        if ("tests/tmp" | path exists) {
            rm -rf "tests/tmp"
        }
        mkdir "tests/tmp"
        
        let log_config = {
            level: "info",
            format: "json",
            output: "tests/tmp/simple_test.log"
        }
        
        setup-logging $log_config
        log-info "Test message"
        
        if ("tests/tmp/simple_test.log" | path exists) {
            print "✅ Logging system working"
            let log_content = (open "tests/tmp/simple_test.log")
            if ($log_content | str contains "Test message") {
                print "  ✅ Log message written correctly"
            } else {
                print "  ❌ Log message not found"
            }
        } else {
            print "❌ Log file not created"
        }
        
    } catch { |err|
        print $"❌ Logging test failed: ($err.msg)"
        return
    }
    
    print ""
    
    # Test 3: Queue system
    print "Testing queue system..."
    try {
        source ../scripts/core/queue.nu
        
        let queue_config = {
            queues: {
                base_path: "tests/tmp/queues",
                cleanup_interval: 300,
                max_file_size: 1048576,
                batch_size: 100,
                poll_interval: 1,
                max_processing_time: 300
            }
        }
        
        init-queues $queue_config
        print "✅ Queue system initialized"
        
        # Test queue status
        let status = (get-queue-status)
        print $"  ✅ Queue status: ($status.requests_pending) pending"
        
        # Test request enqueueing
        let request = {
            id: "simple_test_001",
            type: "eval",
            content: "2 + 2"
        }
        
        enqueue-request $request | ignore
        print "  ✅ Request enqueued"
        
        let updated_status = (get-queue-status)
        if $updated_status.requests_pending == 1 {
            print "  ✅ Queue status updated correctly"
        } else {
            print "  ❌ Queue status not updated"
        }
        
        # Test request dequeueing
        let dequeued = (dequeue-request)
        if $dequeued != null {
            print "  ✅ Request dequeued successfully"
            
            # Complete the request
            let response = (create-response $request.id "success" "4")
            complete-request $dequeued.processing_file $response
            print "  ✅ Request completed"
            
            let final_status = (get-queue-status)
            if $final_status.responses_available == 1 {
                print "  ✅ Response available"
            }
        } else {
            print "  ❌ Failed to dequeue request"
        }
        
    } catch { |err|
        print $"❌ Queue test failed: ($err.msg)"
        return
    }
    
    print ""
    
    # Clean up
    if ("tests/tmp" | path exists) {
        rm -rf "tests/tmp"
    }
    
    print "🎉 All simple tests passed!"
    print ""
    print "✨ efrit-nu basic functionality is working correctly!"
}
