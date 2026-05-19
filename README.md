User
↓
Nginx Ingress
↓
Sandbox Containers
↓
State Files
↓
Health Monitor
↓
Cleanup Daemon
↓
Outage Simulator
↓
Logs + Archived Logs

                        DevOps Sandbox
                        --------------

A lightweight ephemeral environment orchestration platform built with Docker, Nginx, Bash, and automated lifecycle controllers.

This project provisions isolated sandbox environments on demand, dynamically routes traffic through Nginx, monitors environment health, injects simulated outages, and automatically cleans up expired environments.

                        Features
                        --------

Dynamic ephemeral environment provisioning
Automatic Nginx route generation and reloads
Shared ingress architecture using Docker networking
Health monitoring with state reconciliationmake env NAME=test TTL=300
Environment degradation detection
Simulated outage injection
Recovery workflows
Automatic TTL-based cleanup
Log shipping and archival
Stateful environment metadata tracking
Operational automation through Makefile commands

.
├── demo-app/
│ ├── app.py
│ ├── Dockerfile
│ └── requirements.txt
│
├── envs/
│ └── \*.json
│
├── logs/
│ ├── archived/
│ ├── monitor.log
│ ├── cleanup.log
│ └── outages.log
│
├── monitor/
│ └── health_monitor.sh
│
├── nginx/
│ ├── nginx.conf
│ └── conf.d/
│
├── platform/
│ ├── create_env.sh
│ ├── destroy_env.sh
│ ├── cleanup_daemon.sh
│ └── simulate_outage.sh
│
├── Makefile
└── README.md

Core Components
create_env.sh

Responsible for:

provisioning sandbox containers
generating environment IDs
generating Nginx route configs
reloading Nginx dynamically
creating state files
starting log shipping

Prerequisites

Required tools:

Docker
Make
Bash
jq
curl

Setup Instructions
Clone Repository

git clone https://github.com/Nsix6/MiniControlPlane

    cd devops-sandbox

Build Demo Application

    docker build -t sandbox-demo:optimized ./demo-app

Create Shared Network

    docker network create sandbox-shared-net

Start Nginx

    Start Nginx

Start Health Monitor

    make monitor

Start Cleanup Daemon

    make cleanup

                        Usage Instructions
                        ==================

1.  Create Environment
    make env NAME=test TTL=300

2.  Verify Health
    curl -i http://localhost/env-xxxxxx/health

3.  Simulate Crash Outage
    make outage ENV=env-xxxxxx MODE=crash

4.  Simulate Pause Outage
    make outage ENV=env-xxxxxx MODE=pause

5.  Recover Environment
    make recover ENV=env-xxxxxx

6.  Destroy Environment
    make destroy ENV=env-xxxxxx

                             Known Limitations
                             =================

- No persistent storage for sandbox containers
- No authentication layer
- Single-host deployment only
- No distributed orchestration
- Health monitoring uses polling instead of event streams
- Environment metadata stored locally as JSON files

                            Future Improvements
                            ===================

- automatic self-healing
- Prometheus/Grafana integration
- centralized logging
- Kubernetes migration
- persistent storage support
- distributed orchestration
- Web dashboard

                                Technologies Used
                                =================

Docker
Nginx
Bash
jq
curl
Flask
Gunicorn
GNU Make

                                Final Notes
                                ===========

This project demonstrates the foundations of:

ephemeral infrastructure orchestration
ingress management
lifecycle automation
operational monitoring
fault injection
recovery workflows
environment state reconciliation

using lightweight Unix tooling and container primitives.
