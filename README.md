# cyberdeck
Homelab sur Raspberry Pi 5 — infrastructure auto-hébergée sécurisée
# Cyberdeck — Homelab Raspberry Pi 5

Infrastructure auto-hébergée construite et administrée dans le cadre 
d'une reconversion vers la cybersécurité et l'administration système.

---

## Stack technique

| Composant | Technologie |
|---|---|
| Matériel | Raspberry Pi 5 — 8 Go RAM |
| OS | Debian 12 (Bookworm) |
| Conteneurisation | Docker / Docker Compose |
| Reverse Proxy | Nginx |
| VPN | Tailscale (WireGuard) |
| Pare-feu | UFW / nftables |
| Protection intrusion | Fail2Ban |
| SSL | Certbot / Let's Encrypt |

---

## Services déployés

| Service | Description |
|---|---|
| Filebrowser | Gestionnaire de fichiers auto-hébergé |
| Glances | Monitoring système en temps réel |
| Open WebUI / Ollama | Interface LLM local |
| Dashy | Dashboard de navigation |

---

## Sécurité en place

- SSH par clés uniquement — authentification par mot de passe désactivée
- Pare-feu UFW en mode default deny
- Fail2Ban actif sur SSH, Nginx et Filebrowser
- HTTPS via certificats Let's Encrypt
- HTTP Basic Auth devant les services sensibles
- Défense en profondeur — plusieurs couches indépendantes

---

## Architecture réseau

- Exposition publique via nom de domaine custom
- Reverse proxy Nginx comme unique point d'entrée
- Accès distant sécurisé via VPN Mesh Tailscale
- Conteneurs isolés sur réseau Docker dédié

---

## Objectif

Ce projet est mon terrain d'entraînement pratique. 
Chaque service déployé, chaque règle de sécurité configurée, 
chaque log analysé fait partie d'une formation autodidacte 
vers un poste de Technicien Infrastructure Sécurisée.
