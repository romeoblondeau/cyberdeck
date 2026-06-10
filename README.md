# Cyberdeck — Homelab Raspberry Pi 5

Je construis une infra pour apprendre à voir ce qui s'y passe.
Objectif : analyste SOC / technicien infrastructure sécurisée.

---

## Matériel

| Machine | Rôle |
|---|---|
| Raspberry Pi 5 — 8 Go RAM, Debian 12 | Serveur principal — source de logs |
| Dell Latitude 5420 — 16 Go RAM, Ubuntu | Poste de travail / labo d'analyse |

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
| Nginx | Reverse proxy + page statique publique |
| Glances | Monitoring système en temps réel |
| Maigret | OSINT |

---

## Sécurité en place

- SSH par clés uniquement — authentification par mot de passe désactivée
- SSH restreint à l'interface Tailscale uniquement
- Pare-feu UFW en mode default deny
- Fail2Ban actif sur SSH et Nginx
- HTTPS via certificats Let's Encrypt
- Défense en profondeur — plusieurs couches indépendantes

---

## Études de cas

- [Durcissement SSH : restriction à l'interface Tailscale](Docs/hardening-ssh-tailscale.md) — audit du pare-feu, test d'exposition depuis l'extérieur, application du moindre privilège sans lockout
- [Réduction de surface d'attaque](Docs/reduction-surface-attaque.md) — audit des logs Nginx, suppression des services exposés inutilement
- [Analyse des logs Nginx : reconnaître le bruit du signal](Docs/analyse-logs-nginx.md) — identification de comportements suspects sur le trafic entrant
- [Analyse des logs Nginx : patterns de scan et investigation d'IP](Docs/analyse-logs-nginx-patterns.md) — awk/sort/uniq sur 111k lignes, investigation de scanners industriels
---

## Architecture réseau

- Page publique sur domaine custom `bdwlf-cyberdeck.xyz`
- Reverse proxy Nginx comme unique point d'entrée
- Accès distant sécurisé via VPN mesh Tailscale
- Conteneurs isolés sur réseau Docker dédié
