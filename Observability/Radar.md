Radar is an open-source, modern Kubernetes UI and dashboard designed as a drop-in replacement for the traditional Kubernetes Dashboard. Licensed under Apache 2.0, it is built to provide high-performance, real-time cluster visibility through a sleek single ~30MB binary or an in-cluster Helm chart.
What sets Radar apart in 2026 is its native inclusion of a Model Context Protocol (MCP) server, allowing AI agents and external CLI tools to securely interact with and troubleshoot your cluster without direct administrative API access.
Core Features
• Real-Time Visualizations: Live cluster topology, cross-cluster search, and interactive traffic graphing.
• Built-in Troubleshooting: Provides live streaming logs across multiple containers, an in-browser exec terminal, and an event timeline.
• GitOps & Ecosystem Visibility: Built-in visibility for ArgoCD and Flux setups, alongside native Helm release management.
• AI Agent Friendly: Its MCP server maps resources like deployments, pods, and logs so that autonomous agents can run cluster diagnostics safely.

Comparison: Traditional K8s Dashboard vs. Radar

Feature	        Traditional Kubernetes Dashboard	          Radar (skyhook-io/radar)
Architecture	Heavy multi-service structure / archived	  Single ~30MB binary or Helm chart
Authentication	Manual kubectl proxy + copying tokens	      Local kubeconfig RBAC or native OIDC SSO
AI Integration	None	                                      Native Model Context Protocol (MCP) server
Observability	Static resource lists	                      Live traffic maps & unified SQLite/Cloud timelines


https://radarhq.io/ 