Homelab Stack

⚠️ Notice: This project is in very early development. Features may be incomplete, unstable, or subject to breaking changes. Use at your own risk.

A Docker Compose‑based homelab stack designed for media, self‑hosting, and automation services. The stack leverages a VPN container and Traefik reverse proxy for secure, domain‑based access.

🚀 Features

Modular service definitions for media servers, sync tools, automation bots, dashboards, and document management.

VPN routing for containers via a dedicated VPN client (e.g., gluetun).

Reverse proxy with Traefik for domain‑based service access.

Environment-variable-driven configuration for flexibility.

Designed for easy integration of new services as your homelab grows.

🧰 Core Services

Examples of services included or intended for integration:

Media: Jellyfin, Recomendarr

Sync / Cloud: Nextcloud, Syncthing

Automation / Indexing: Cross-Seed, Autobrr

Monitoring & Dashboards: Uptime Kuma

Document Management: Paperless/ngx

🔧 Key Features & Notes

Containers use network_mode: "service:gluetun" by default for VPN routing.

Traefik handles secure external access via your configured DNS provider (e.g., Cloudflare).

Labels, routers, and middleware can be customized for authentication and security.

🎯 Best Practices

Keep secrets (API tokens, credentials) private.

Regularly monitor service logs and container health.

Consider backups for critical data stored in persistent volumes.

🤝 Contributions & Support

Feel free to open issues or pull requests for improvements.

This project is intended as a starting point for your own homelab stack; customization is expected.
