#  Centralisation des logs avec Promtail / Loki / Grafana

## Objectif

Mettre en place un pipeline de centralisation des logs depuis le Pi vers le Dell, afin de visualiser en temps réel les événements Nginx et Cowrie dans Grafana.

---

## Architecture du pipeline

```
Pi (bdwlf-cyberdeck)          Dell (bdwlf-terminal)
┌─────────────────┐           ┌──────────────────────┐
│   Nginx logs    │           │                      │
│   Cowrie logs   │──Promtail──▶ Loki ──▶ Grafana   │
│ (via Docker)    │  Tailscale │                      │
└─────────────────┘           └──────────────────────┘
```

- **Promtail** : agent installé sur le Pi, scrape les logs et les envoie à Loki
- **Loki** : agrégateur de logs installé sur le Dell, reçoit et stocke les logs
- **Grafana** : interface de visualisation installée sur le Dell, interroge Loki

---

## Installation

### Dell — Loki + Grafana (`~/docker/monitoring/docker-compose.yml`)

```yaml
services:
  grafana:
    image: grafana/grafana
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - 'grafana_storage:/var/lib/grafana'

  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: always
    ports:
      - "3100:3100"
    volumes:
      - './loki-config.yaml:/etc/loki/local-config.yaml'
    command: -config.file=/etc/loki/local-config.yaml

volumes:
  grafana_storage: {}
```

### Pi — Promtail (`~/docker/promtail/docker-compose.yml`)

```yaml
services:
  promtail:
    image: grafana/promtail
    container_name: promtail
    user: root
    restart: always
    ports:
      - "9080:9080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/home/badwolf01/docker/nginx-proxy/logs:/var/log/nginx:ro"
      - "./promtail-config.yml:/etc/promtail/config.yml"
      - "/var/lib/docker/containers:/var/lib/docker/containers:ro"
    command: -config.file=/etc/promtail/config.yml
```

### Pi — Config Promtail (`~/docker/promtail/promtail-config.yml`)

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://100.125.13.115:3100/loki/api/v1/push

scrape_configs:
  - job_name: nginx-proxy
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/nginx/access.log

  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container
      - source_labels: [__meta_docker_container_name]
        regex: /cowrie
        action: keep
      - source_labels: [__meta_docker_container_id]
        target_label: __path__
        replacement: /var/lib/docker/containers/$1/$1-json.log
```

---

## Problèmes rencontrés

### 1. Filtre Cowrie qui bloque tout

**Symptôme** : aucun log Docker n'arrive dans Loki malgré la config `docker_sd_configs`.

**Cause** : Docker préfixe les noms de conteneurs avec `/` — le conteneur s'appelle `/cowrie` et non `cowrie`. Le `regex: cowrie` ne matchait pas, et `action: keep` bloquait donc tous les logs.

**Solution** : corriger le regex en `regex: /cowrie`.

---

### 2. Promtail ne peut pas lire les logs Docker

**Symptôme** : Promtail découvre les conteneurs via le socket Docker mais ne lit aucun fichier de log.

**Cause** : les fichiers de logs Docker sont stockés dans `/var/lib/docker/containers/`, un dossier appartenant à `root` avec des permissions `drwx--x---`. Le conteneur Promtail tournait sans les droits suffisants.

**Solution** : ajouter `user: root` dans le `docker-compose.yml` de Promtail.

---

### 3. Logs absents dans Grafana (fenêtre temporelle)

**Symptôme** : la requête `{container="/cowrie"}` ne retourne rien dans Grafana.

**Cause** : la fenêtre temporelle par défaut de Grafana (30 minutes) ne couvrait pas les derniers événements Cowrie.

**Solution** : étendre la fenêtre temporelle à 3h ou 6h selon l'activité.

---

## Note — Docker et UFW ne se parlent pas

En testant l'accès au port 3100 de Loki depuis le Pi, on a constaté que le trafic passait malgré l'absence de règle UFW explicite sur le Dell.

**Explication** : Docker écrit ses règles directement dans la table `nat` d'iptables, dans la chaîne `PREROUTING`. UFW, lui, gère la chaîne `INPUT`. Les paquets destinés à un port publié par Docker sont interceptés et redirigés via DNAT **avant** d'atteindre les règles UFW — qui ne les voit donc jamais.

Ce comportement est documenté par Docker lui-même. Il ne s'agit pas d'un bug mais d'une incompatibilité architecturale entre les deux systèmes. En production, cela représente un vrai risque : un port exposé par Docker est accessible depuis l'extérieur même si UFW indique qu'il est bloqué.

Sur un labo personnel comme le Dell, ce n'est pas critique — mais c'est un point à retenir pour toute infrastructure exposée.

---

## Résultat

Pipeline opérationnel :

- Logs Nginx visibles dans Grafana via `{job="varlogs"}`
- Logs Cowrie visibles dans Grafana via `{container="/cowrie"}`
- Transmission chiffrée Pi → Dell via Tailscale (WireGuard)

**Prochaine étape** : construction des dashboards Grafana (panels Nginx et Cowrie).
