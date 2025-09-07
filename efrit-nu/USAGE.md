# Efrit-Nu Usage Guide

## Current Status: Alpha (Core Systems Working)

Efrit-Nu is a high-performance port of efrit from Emacs Lisp to Nushell. **Core functionality is working** but this is still early-stage software.

### ✅ What Works
- **Configuration management** - Full system (5/5 tests pass)
- **Queue operations** - Core functionality working  
- **Performance testing** - Benchmarking framework operational
- **Docker deployment** - Containers build and run successfully
- **Basic logging** - File operations working

### 🔧 In Development  
- LLM provider integrations
- Tool execution system
- Advanced queue processing
- Web interface

## Quick Start

### 1. Build and Start

```bash
cd efrit-nu

# Build containers
docker-compose build efrit-nu
docker-compose --profile dev build efrit-nu-dev

# Start development environment  
docker-compose --profile dev up -d efrit-nu-dev
```

### 2. Test Core Systems

```bash
# Access development shell
docker-compose exec efrit-nu-dev nu

# Test configuration system
cd /workspace/efrit-nu
use scripts/utils/config.nu *
load-config

# Test queue operations
use scripts/core/queue.nu *
init-queues
get-queue-status
```

### 3. Run System Tests

```bash
# Inside container or from host
cd /workspace/efrit-nu
nu tests/run_all_tests.nu
```

**Expected Results:**
- ✅ Configuration tests: 5/5 pass
- 🔧 Logging tests: Core works, test framework issues  
- ✅ Queue tests: 3/8 pass (core functionality working)
- ✅ Performance tests: Complete successfully

## Core Operations

### Configuration Management
```nushell
# Load system configuration
use scripts/utils/config.nu *
let config = (load-config)

# Access specific sections
$config.system    # System settings
$config.queues    # Queue configuration  
$config.providers # LLM provider settings
```

### Queue Operations
```nushell
use scripts/core/queue.nu *

# Initialize queue directories
init-queues

# Check queue status
get-queue-status

# Create a test request
let request = {
    id: (generate-request-id),
    type: "eval",
    content: "2 + 2",
    options: {}
}

# Enqueue request
enqueue-request $request

# Check status again
get-queue-status
```

### Logging System  
```nushell
use scripts/utils/logging.nu *

# Setup logging
setup-logging {
    level: "debug",
    format: "json", 
    output: "data/logs/efrit.log"
}

# Log messages
log-info "System started"
log-warn "This is a warning"
log-error "This is an error"
```

## Development Workflow

### 1. Container Development
```bash
# Start dev container
docker-compose --profile dev up -d efrit-nu-dev

# Access shell
docker-compose exec efrit-nu-dev nu

# Make changes to files (mounted as volumes)
# Test changes immediately
```

### 2. Testing Changes
```bash
# Run specific test suites
cd /workspace/efrit-nu

# Configuration tests (fully working)
nu -c "use tests/unit/config_test.nu *; run_config_tests"

# Queue tests (partially working)  
nu -c "use tests/unit/queue_test.nu *; run_queue_tests"
```

### 3. Performance Testing
```bash
# Run performance benchmarks
nu -c "use tests/run_all_tests.nu *; run_performance_tests"

# Results show:
# - Config loading: ~40ms for 10 iterations
# - Queue operations: ~930ms for 100 requests
```

## Configuration

### System Settings (`config/system.toml`)
```toml
[system]
log_level = "info"
max_concurrent_requests = 10
request_timeout = 30

[queues]  
base_path = "data/queues"
cleanup_interval = 300
max_file_size = 1048576

[providers]
default = "anthropic"  # Not yet implemented
timeout = 30
retry_attempts = 3
```

### Environment Variables
```bash
export EFRIT_LOG_LEVEL=debug
export EFRIT_ENV=development  
export EFRIT_DATA_DIR=/custom/data/path
```

## Current Limitations

1. **LLM Providers**: Configuration exists but integration not implemented
2. **Tool Execution**: Framework planned but not built  
3. **Web Interface**: Container ready but endpoints not implemented
4. **Advanced Features**: Session management, authentication, etc.

## File Structure

```
efrit-nu/
├── scripts/              # ✅ Core Nushell functionality  
│   ├── core/            # ✅ Queue, session management
│   ├── providers/       # 🔧 LLM provider stubs
│   ├── tools/           # 🔧 Tool execution stubs  
│   └── utils/           # ✅ Config, logging utilities
├── config/              # ✅ Working configuration
├── data/                # ✅ Runtime data directories
├── tests/               # ✅ Test suites (partially working)
└── docker/              # ✅ Container definitions
```

## Next Steps for Development

1. **Complete queue system**: Fix remaining test failures
2. **LLM provider integration**: Start with Anthropic/OpenAI
3. **Tool execution**: Container-based command execution
4. **Web API**: REST endpoints for external access

## Getting Help

- Check `tests/` directory for working examples
- Use `nu -h <command>` for Nushell help
- Monitor logs in `data/logs/efrit-nu.log`
- Container logs: `docker-compose logs efrit-nu-dev`

---

*This is alpha software. Core systems work but expect breaking changes.*
