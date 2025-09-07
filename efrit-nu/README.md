# Efrit-Nu: High-Performance AI Agent Communication System

A complete port of [efrit](https://github.com/steveyegge/efrit) from Emacs Lisp to Nushell, designed for high-performance, container-native AI agent communication with multi-provider LLM support.

## 🚀 Features

- **Zero Client-Side Intelligence**: Pure executor model with LLM-driven decision making
- **Multi-Provider Support**: Anthropic Claude, OpenAI GPT, Ollama (local models)
- **Container-Native**: Docker-based execution with security isolation
- **Structured Data**: Leverages Nushell's native structured data handling
- **High Performance**: Async processing, caching, and intelligent routing
- **Cross-Platform**: Linux-first with container portability

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Efrit-Nu System                         │
├─────────────────────────────────────────────────────────────┤
│  Queue Management → LLM Providers → Tool Execution         │
│  Context Gathering → Session Management → Performance      │
└─────────────────────────────────────────────────────────────┘
```

See [NUSHELL_ARCHITECTURE.md](NUSHELL_ARCHITECTURE.md) for detailed design documentation.

## 🛠️ Development Status

**Current Phase**: 1.1 - Core Infrastructure ✅
- [x] Project structure and configuration system
- [x] Logging and monitoring framework
- [x] Basic queue management system
- [x] Docker containers (base + development)

**Next Phase**: 1.2 - Queue System Foundation
- [ ] Message protocol and validation
- [ ] Request/response processing
- [ ] Error handling and recovery

See [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) for the complete development plan.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Linux environment (other platforms via Docker)

### Development Environment

1. **Build the development container**:
   ```bash
   cd efrit-nu
   docker-compose --profile dev build efrit-nu-dev
   ```

2. **Start development environment**:
   ```bash
   docker-compose --profile dev up -d efrit-nu-dev
   ```

3. **Access development shell**:
   ```bash
   docker-compose exec efrit-nu-dev nu
   ```

4. **Test the system**:
   ```nushell
   # Load configuration
   source scripts/utils/config.nu
   load-config
   
   # Test logging
   source scripts/utils/logging.nu
   setup-logging
   log-info "Testing efrit-nu system"
   
   # Test queue system
   source scripts/core/queue.nu
   init-queues
   get-queue-status
   ```

### Production Deployment

1. **Build base container**:
   ```bash
   docker-compose build efrit-nu
   ```

2. **Start efrit-nu**:
   ```bash
   docker-compose up -d efrit-nu
   ```

3. **Check status**:
   ```bash
   docker-compose logs efrit-nu
   docker-compose exec efrit-nu nu -c "source scripts/core/queue.nu; get-queue-status"
   ```

## 📁 Project Structure

```
efrit-nu/
├── scripts/              # Core Nushell scripts
│   ├── core/            # System components (queue, session, context)
│   ├── providers/       # LLM provider implementations  
│   ├── tools/           # Tool execution scripts
│   └── utils/           # Utilities (config, logging, etc.)
├── docker/              # Container definitions
├── config/              # Configuration files
├── data/                # Runtime data (queues, logs, cache)
├── tests/               # Test suites
└── docs/                # Documentation
```

## 🔧 Configuration

### System Configuration (`config/system.toml`)
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
default = "anthropic"
timeout = 30
retry_attempts = 3
```

### Provider Configuration (`config/providers.toml`)
```toml
[anthropic]
model = "claude-3-5-sonnet-20241022"
max_tokens = 8192
# Set ANTHROPIC_API_KEY environment variable

[ollama]
base_url = "http://localhost:11434"
model = "llama3.2:latest"
# No API key required for local
```

## 🧪 Development Commands

Inside the development container:

```nushell
# Reload scripts
dev-reload

# View logs
dev-logs

# Run tests (future)
dev-test

# Check queue status
source scripts/core/queue.nu; get-queue-status

# Test configuration
source scripts/utils/config.nu; load-config

# Manual queue processing
source scripts/core/queue.nu; start-queue-processor
```

## 🔌 LLM Provider Setup

### Anthropic Claude
```bash
export ANTHROPIC_API_KEY="your-api-key"
```

### Ollama (Local)
```bash
# Start Ollama service
docker-compose --profile ollama up -d ollama

# Pull a model
docker-compose exec ollama ollama pull llama3.2
```

### OpenAI
```bash
export OPENAI_API_KEY="your-api-key"
```

## 🔍 Monitoring

Start monitoring stack:
```bash
docker-compose --profile monitoring up -d prometheus grafana
```

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

## 🧪 Testing

### Manual Testing
```nushell
# Test request processing
let request = {
    id: (generate-request-id),
    type: "eval", 
    content: "2 + 2"
}

enqueue-request $request
```

### Unit Tests (Coming Soon)
```bash
docker-compose exec efrit-nu-dev nu -c "use tests/unit/*.nu; run-all-tests"
```

## 🤝 Contributing

1. **Development Environment**: Use the dev container for consistency
2. **Code Style**: Follow Nushell conventions and efrit principles
3. **Testing**: Add tests for new functionality
4. **Documentation**: Update README and architecture docs

## 📊 Performance Targets

- **Latency**: < 100ms for simple requests
- **Throughput**: > 1000 requests/minute  
- **Resource**: < 512MB memory per container
- **Availability**: 99.9% uptime

## 🔒 Security

- **Container Isolation**: All tool execution in isolated containers
- **Resource Limits**: CPU and memory constraints
- **Input Validation**: Strict request/response validation
- **Audit Logging**: Complete operation trail

## 📚 Documentation

- [Architecture Design](NUSHELL_ARCHITECTURE.md) - Complete system architecture
- [Development Roadmap](DEVELOPMENT_ROADMAP.md) - Project timeline and phases
- [Original Efrit](https://github.com/steveyegge/efrit) - Reference implementation

## 📄 License

Licensed under the Apache License, Version 2.0. See [LICENSE](../LICENSE) for details.

---

*Efrit-Nu: High-performance AI agent communication powered by Nushell and containers.*
