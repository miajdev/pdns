# pdns-auth (PowerDNS Authoritative, Alpine, MySQL backend)

Lean Alpine build of PowerDNS Authoritative Server **5.0.0** with gmysql backend.
- API + webserver enabled via env
- Multi-arch images (amd64/arm64)
- Ready for GHCR or Docker Hub

## Quick start (local)
```bash
cp .env.example .env
docker compose up -d --build
curl -s -H "X-API-Key: $PDNS_API_KEY" http://127.0.0.1:8081/api/v1/servers/localhost
