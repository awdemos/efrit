#!/bin/bash
set -e

# Development entrypoint script for efrit-nu

echo "🚀 Starting efrit-nu development environment"

# Create necessary directories if they don't exist
mkdir -p /app/data/{queues/{requests,processing,responses,archive},sessions,logs,cache}

# Set up development permissions
sudo chown -R efrit:efrit /app/data /workspace

# Initialize logging
if [ ! -f /app/data/logs/efrit-nu.log ]; then
    touch /app/data/logs/efrit-nu.log
fi

# Check if Docker daemon is available (for container-in-container)
if command -v docker &> /dev/null; then
    echo "✅ Docker CLI available"
    if docker ps &> /dev/null; then
        echo "✅ Docker daemon accessible"
    else
        echo "⚠️  Docker daemon not accessible (mount Docker socket for container-in-container)"
    fi
else
    echo "⚠️  Docker CLI not available"
fi

# Check Nushell version
echo "📦 Nushell version: $(nu --version)"

# Initialize efrit-nu configuration
cd /app
nu -c "
    source scripts/utils/config.nu; 
    source scripts/utils/logging.nu; 
    setup-logging;
    log-info 'Development environment initialized' --component 'dev';
    echo '✅ Efrit-nu configuration loaded'
"

# Check provider configurations
echo "🔧 Checking provider configurations..."
if [ -f /app/config/providers.toml ]; then
    echo "✅ Provider configuration found"
else
    echo "⚠️  Provider configuration not found"
fi

# Show development commands
echo ""
echo "🛠️  Development Commands Available:"
echo "  dev-reload    - Reload all nu scripts"
echo "  dev-test      - Run unit tests" 
echo "  dev-logs      - Tail application logs"
echo "  start-queue-processor - Start the queue processor"
echo ""

# Export helpful aliases
export EFRIT_DEV_ALIASES="
alias ll = ls -la
alias log = tail -f /app/data/logs/efrit-nu.log
alias config = open /app/config/system.toml
alias queue-status = nu -c 'source /app/scripts/core/queue.nu; get-queue-status'
"

echo "🎉 Development environment ready!"
echo "💡 Run 'nu' to start interactive Nushell session"

# Execute the command passed to the container
exec "$@"
