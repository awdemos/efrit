# Unit tests for queue system
# Tests the queue.nu module functionality

use ../../scripts/core/queue.nu *

# Setup test environment
export def setup_test_queue [] {
    let test_config = {
        queues: {
            base_path: "tests/tmp/queues",
            cleanup_interval: 300,
            max_file_size: 1048576,
            batch_size: 100,
            poll_interval: 1,
            max_processing_time: 300
        }
    }
    
    # Clean up any existing test data
    if ("tests/tmp" | path exists) {
        rm -rf "tests/tmp"
    }
    
    init-queues $test_config
    
    $test_config
}

# Test queue initialization
export def test_queue_initialization [] {
    let config = (setup_test_queue)
    
    # Check that all queue directories were created
    let queue_dirs = ["requests", "processing", "responses", "archive"]
    let base_path = $config.queues.base_path
    
    for dir in $queue_dirs {
        let full_path = ($base_path | path join $dir)
        if not ($full_path | path exists) {
            error make { msg: $"Queue directory not created: ($full_path)" }
        }
    }
    
    print "✅ Queue initialization test passed"
    true
}

# Test request ID generation
export def test_request_id_generation [] {
    let id1 = (generate-request-id)
    let id2 = (generate-request-id)
    
    # IDs should be different
    if $id1 == $id2 {
        error make { msg: "Generated request IDs should be unique" }
    }
    
    # IDs should follow expected format
    if not ($id1 | str starts-with "efrit_") {
        error make { msg: "Request ID should start with 'efrit_'" }
    }
    
    print "✅ Request ID generation test passed"
    true
}

# Test request validation
export def test_request_validation [] {
    # Test valid request
    let valid_request = {
        id: "test_123",
        type: "eval",
        content: "2 + 2"
    }
    
    let validation_result = (validate-request $valid_request)
    
    if not $validation_result.valid {
        error make { msg: $"Valid request failed validation: ($validation_result.error)" }
    }
    
    # Test invalid request - missing required field
    let invalid_request = {
        id: "test_123",
        type: "eval"
        # Missing content field
    }
    
    let invalid_result = (validate-request $invalid_request)
    
    if $invalid_result.valid {
        error make { msg: "Invalid request should have failed validation" }
    }
    
    # Test invalid request type
    let invalid_type_request = {
        id: "test_123",
        type: "invalid_type",
        content: "test"
    }
    
    let invalid_type_result = (validate-request $invalid_type_request)
    
    if $invalid_type_result.valid {
        error make { msg: "Invalid request type should have failed validation" }
    }
    
    print "✅ Request validation test passed"
    true
}

# Test request enqueueing
export def test_request_enqueueing [] {
    setup_test_queue | ignore
    
    let request = {
        id: (generate-request-id),
        type: "eval",
        content: "2 + 2"
    }
    
    let request_id = (enqueue-request $request)
    
    if $request_id != $request.id {
        error make { msg: "Enqueue should return the request ID" }
    }
    
    # Check that request file was created
    let request_file = ("tests/tmp/queues/requests" | path join ($request.id + ".json"))
    
    if not ($request_file | path exists) {
        error make { msg: $"Request file not created: ($request_file)" }
    }
    
    # Check file contents
    let file_content = (open $request_file)
    
    if $file_content.id != $request.id {
        error make { msg: "Request file content incorrect" }
    }
    
    if ($file_content | get metadata -o | default null) == null {
        error make { msg: "Request metadata not added during enqueue" }
    }
    
    print "✅ Request enqueueing test passed"
    true
}

# Test queue status
export def test_queue_status [] {
    setup_test_queue | ignore
    
    # Initially should be empty
    let initial_status = (get-queue-status)
    
    let expected_fields = ["requests_pending", "requests_processing", "responses_available", "requests_archived", "total_processed"]
    
    for field in $expected_fields {
        if ($initial_status | get $field -o) == null {
            error make { msg: $"Missing field in queue status: ($field)" }
        }
    }
    
    # All counts should be 0 initially
    if $initial_status.requests_pending != 0 {
        error make { msg: "Initial queue should have 0 pending requests" }
    }
    
    # Add a request and check status changes
    let request = {
        id: (generate-request-id),
        type: "eval", 
        content: "test"
    }
    
    enqueue-request $request | ignore
    
    let updated_status = (get-queue-status)
    
    if $updated_status.requests_pending != 1 {
        error make { msg: "Queue status should show 1 pending request after enqueue" }
    }
    
    print "✅ Queue status test passed"
    true
}

# Test request dequeueing
export def test_request_dequeueing [] {
    setup_test_queue | ignore
    
    # First enqueue a request
    let request = {
        id: (generate-request-id),
        type: "eval",
        content: "test"
    }
    
    enqueue-request $request | ignore
    
    # Now dequeue it
    let dequeued_data = (dequeue-request)
    
    if $dequeued_data == null {
        error make { msg: "Should have dequeued a request" }
    }
    
    if $dequeued_data.request.id != $request.id {
        error make { msg: "Dequeued wrong request" }
    }
    
    # Check that file was moved to processing
    let processing_file = $dequeued_data.processing_file
    
    if not ($processing_file | path exists) {
        error make { msg: "Request file not moved to processing directory" }
    }
    
    # Check that original file was removed from requests
    let original_file = ("tests/tmp/queues/requests" | path join ($request.id + ".json"))
    
    if ($original_file | path exists) {
        error make { msg: "Original request file not removed after dequeue" }
    }
    
    print "✅ Request dequeueing test passed"
    true
}

# Test response creation and enqueueing
export def test_response_handling [] {
    setup_test_queue | ignore
    
    let request_id = "test_response_123"
    
    # Test successful response
    let success_response = (create-response $request_id "success" "42")
    
    if $success_response.id != $request_id {
        error make { msg: "Response ID incorrect" }
    }
    
    if $success_response.status != "success" {
        error make { msg: "Response status incorrect" }
    }
    
    if $success_response.result != "42" {
        error make { msg: "Response result incorrect" }
    }
    
    # Test error response  
    let error_response = (create-response $request_id "error" "" "Test error")
    
    if $error_response.error != "Test error" {
        error make { msg: "Response error incorrect" }
    }
    
    # Test response enqueueing
    let response_id = (enqueue-response $success_response)
    
    if $response_id != $request_id {
        error make { msg: "Response enqueueing should return request ID" }
    }
    
    # Check response file was created
    let response_file = ("tests/tmp/queues/responses" | path join ($request_id + ".json"))
    
    if not ($response_file | path exists) {
        error make { msg: "Response file not created" }
    }
    
    print "✅ Response handling test passed"
    true
}

# Test complete request workflow
export def test_complete_workflow [] {
    setup_test_queue | ignore
    
    # Create and enqueue request
    let request = {
        id: (generate-request-id),
        type: "eval",
        content: "2 + 2"
    }
    
    enqueue-request $request | ignore
    
    # Dequeue request
    let dequeued_data = (dequeue-request)
    let processing_file = $dequeued_data.processing_file
    
    # Create and complete request
    let response = (create-response $request.id "success" "4")
    complete-request $processing_file $response
    
    # Check that processing file was moved to archive
    if ($processing_file | path exists) {
        error make { msg: "Processing file should have been archived" }
    }
    
    # Check that response was created
    let response_file = ("tests/tmp/queues/responses" | path join ($request.id + ".json"))
    
    if not ($response_file | path exists) {
        error make { msg: "Response file should have been created" }
    }
    
    # Check queue status reflects completion
    let status = (get-queue-status)
    
    if $status.requests_pending != 0 {
        error make { msg: "Should have 0 pending requests after completion" }
    }
    
    if $status.responses_available != 1 {
        error make { msg: "Should have 1 available response after completion" }
    }
    
    print "✅ Complete workflow test passed"
    true
}

# Clean up test files
export def cleanup_test_queue [] {
    if ("tests/tmp" | path exists) {
        rm -rf "tests/tmp"
    }
    
    print "🧹 Test queue files cleaned up"
}

# Run all queue tests
export def run_queue_tests [] {
    print "🧪 Running queue system tests..."
    
    mut passed = 0
    mut total = 8
    
    try {
        test_queue_initialization
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_queue_initialization failed: ($err.msg)"
    }
    
    try {
        test_request_id_generation
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_request_id_generation failed: ($err.msg)"
    }
    
    try {
        test_request_validation
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_request_validation failed: ($err.msg)"
    }
    
    try {
        test_request_enqueueing
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_request_enqueueing failed: ($err.msg)"
    }
    
    try {
        test_queue_status
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_queue_status failed: ($err.msg)"
    }
    
    try {
        test_request_dequeueing
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_request_dequeueing failed: ($err.msg)"
    }
    
    try {
        test_response_handling
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_response_handling failed: ($err.msg)"
    }
    
    try {
        test_complete_workflow
        $passed = ($passed + 1)
    } catch { |err|
        print $"❌ Test test_complete_workflow failed: ($err.msg)"
    }
    
    # Clean up after tests
    cleanup_test_queue
    
    print $"📊 Queue tests: ($passed)/($total) passed"
    
    if $passed == $total {
        print "🎉 All queue tests passed!"
        true
    } else {
        error make { msg: $"($total - $passed) queue tests failed" }
    }
}
