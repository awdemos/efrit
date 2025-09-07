> Efrit-Nu is a high-performance, fully open-source agent orchestration and communication platform, designed to let any shell-based or external AI agent interact autonomously through a strict request/response queueing system. It is a faithful port of Steve Yegge’s Emacs-native efrit Elisp agent, but realized in Nushell for containers, and replaces Emacs-centric interaction with structured pipelines, making it suitable for modern, composable, and container-native workflow automation.[1]

***

## Core Purpose

Efrit-Nu **enables fast, robust communication between LLM-powered agents and external tools** in a highly auditable, containerized, and open environment using Nushell scripts as the backbone.[1]

- Everything is driven by **file-based queues** (requests, responses, processing, archive) using structured JSON.
- Agents (LLMs, local models, or other automation entities) submit "job" JSON files—a request to evaluate code, run a tool, or perform a command—into the queue, and then await structured results.
- There is **no intelligence on the client:** workflow logic, tool selection, context management, and execution separation are defined server-side, with agents acting as pure executors.
- Built for **multi-provider support** (Anthropic Claude, OpenAI, Ollama, etc.), with easy addition of custom or local models via TOML config.

***

## System Architecture

- **Queue Management**: Central feature; directories for incoming requests, responses, jobs-in-progress, and completed jobs (archived).  
- **Structured Job/Result Contracts**: Each request is validated, enriched with metadata, and lifecycle-managed (enqueue, dequeue, processing, archive, response).[1]
- **Isolation by Containerization**: The entire orchestration runs isolated in containers, optionally spinning up tools or agents in further isolated environments (via Docker).
- **Configurable, Auditable Logging**: All actions are logged in JSON for traceability, enabling detailed auditing and observability for every operation.
- **Provider-Agnostic Routing**: System-level TOML config enables dynamic routing of requests by type (eval, chat, command), size, or failure states.
- **Asynchronous Processing**: Event loop (queue processor) picks up requests, processes via LLM/tool backend, writes response, and archives requests—never blocking on the shell.[1]

***

## Usage Model

- **Agents (or users)** drop a JSON file into the `requests/` queue directory.
    - Example:  
      ```json
      {
        "id": "job_123",
        "type": "eval",
        "content": "2 + 2"
      }
      ```
- **Efrit-Nu’s processor** (a Nushell command) monitors for new files:
    - Validates, moves to `processing/`, runs the request (e.g., sends to LLM or calls a shell tool).
    - Creates a response JSON and places it in `responses/`, moves original request to `archive/`.
- **Clients/agents** retrieve their result from `responses/`, ensuring clear decoupling and robust error handling.
- **Logging and metrics** are written in a structured, append-only format, ready for ingestion by Prometheus/Grafana/etc.[1]

***

## Design Philosophy and Target Scenarios

- **No editor lock-in**—automation runs as first-class CLI services via open-source Nushell, not an editor.
- **Polyglot agent model**—LLMs, local models, or scripting bots can all participate by writing/reading JSON files.
- **Maximum auditability and predictability**—all operations are transparent, logged, and controllable via config.
- **Production-oriented**—containers, strict resource limits, and monitoring out of the box; designed to handle high throughput (1000+ jobs/min) and large pipelines.
- **Security and isolation**—jobs can be run in sandboxes, locked down, and never get raw shell access; only the orchestrator interacts with host system.[1]

***

## Example Applications

- Run AI-assisted code review in CI/CD by a local job queue instead of SaaS.
- Batch code transformations, formatted by structure, with LLM or local-agent review and validation.
- Automated data processing pipelines: LLM decides which shell tools to call, orchestrated and sandboxed via queue contracts.
- Bring-your-own intelligence: plug in new models, switch tools, and reroute jobs by changing a TOML file, not your logic.

***

## Comparison to the Original efrit.el

|                      | **efrit.el (Emacs)**               | **efrit-nu (Nushell)**                      |
|----------------------|------------------------------------|---------------------------------------------|
| Core language        | Elisp                              | Nushell                                     |
| Environment          | Emacs-centric                      | Container-native, shell-first               |
| Job format           | File queue with JSON               | File queue with JSON                        |
| LLM tool support     | Anthropic (Claude)                 | Anthropic, OpenAI, Ollama, extensible[1] |
| Execution Context    | Emacs buffer/tools                 | Shell tool, code eval, pipelines            |
| Isolation            | None/Emacs                         | Strong container isolation                  |
| Monitoring           | Minimal, Emacs buffers             | Full Prometheus/Grafana-ready metrics       |
| Target workflow      | Editor automation & code agents    | General agent orchestration & automation    |

***

## What It Actually Runs

The repository implements, in Nushell:
- A **config loader/validator** (with TOML and env support).
- A **modular, fully tested queue system** (implementing enqueue-dequeue-processing-complete-archive for jobs).
- **Logging subsystem** (structured, append-only, multi-level).
- **Containerized runtime** (Docker/Docker Compose, dev and prod profiles).
- **Extensible LLM/provider modules** (config only; Anthropic, OpenAI, Ollama stubbed).
- **Partial test and benchmarking suite**—integrated, performance testing, strong contracts.

Even in alpha, all core queue, config, and logging logic is covered by working tests and designed for high extensibility and auditability.[1]

***

**Summary:**  
Efrit-Nu is designed to be the backbone of modular, auditable, containerized, open-source agent ecosystems for LLM-driven development, automation, and self-improving bots—using Nushell as its foundation and file-based queues as the universal API between clients, agents, and tools.[1]
