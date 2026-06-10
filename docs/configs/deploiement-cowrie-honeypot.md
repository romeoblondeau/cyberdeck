# Déploiement de Cowrie : honeypot SSH sur le Cyberdeck

> Installation et configuration d'un honeypot SSH en conteneur Docker — pour observer les attaquants plutôt que de simplement les bloquer.

**Contexte :** Raspberry Pi 5, Debian 12, Docker Compose. Suite logique de l'analyse des logs Nginx — passer de l'observation passive à la capture active.

---

## Pourquoi un honeypot

L'analyse des logs Nginx a montré que le serveur est activement scanné : tentatives de récupération de fichiers `.env`, encodage URL pour contourner les filtres, infrastructures de scan industriel. Mais les logs Nginx ne montrent que des requêtes HTTP — des tentatives bloquées.

Un honeypot SSH permet d'aller plus loin : laisser les attaquants "entrer" dans un environnement simulé et observer ce qu'ils font une fois à l'intérieur. Commandes tapées, outils téléchargés, comportements post-intrusion.

---

## Cowrie

Cowrie est un honeypot SSH open source qui simule un environnement Linux complet. Il accepte toutes les connexions, enregistre tout — mots de passe testés, commandes tapées, fichiers manipulés — et renvoie des réponses crédibles à l'attaquant.

L'attaquant pense avoir compromis un vrai serveur. Cowrie enregistre chaque action.

---

## Choix du port

Cowrie est exposé sur le port **2222**, pas le 22.

Le port 22 est déjà utilisé par le SSH réel du Pi, restreint à l'interface Tailscale. Utiliser un port séparé clarifie l'architecture — les logs du honeypot sont distincts du SSH légitime — et évite toute ambiguïté entre trafic réel et trafic capturé.

---

## Déploiement

### docker-compose.yml

```yaml
services:
  cowrie:
    image: cowrie/cowrie      # Image officielle du honeypot Cowrie
    container_name: cowrie    # Nom du conteneur
    restart: always           # Redémarre automatiquement si le Pi reboot
    ports:
      - "2222:2222"           # Port SSH du honeypot — exposé sur Internet, pas le vrai SSH
    volumes:
      - cowrie-var:/cowrie/cowrie-git/var  # Logs et données — géré par Docker

volumes:
  cowrie-var:    # Déclaration du volume nommé — Docker gère les permissions
```

### Problème rencontré : permissions

Premier essai avec un bind mount vers `~/docker/cowrie/logs/` — Cowrie ne pouvait pas écrire dans le dossier. Le processus dans le conteneur tourne sous l'utilisateur `cowrie`, qui n'a pas les droits sur un dossier appartenant à `badwolf01` sur le Pi.

```
PermissionError(13, 'Permission denied')
FileNotFoundError: var/log/cowrie/cowrie.json
```

**Solution choisie :** volume nommé Docker. Docker gère les permissions lui-même — plus de conflit d'utilisateurs. Les logs sont accessibles via `docker logs cowrie` et `docker exec`.

Ce choix est cohérent avec l'objectif à terme : centraliser les logs dans Loki/Grafana, pas les lire directement sur le Pi.

---

## Vérification

```bash
docker logs cowrie
# 2026-06-10T10:35:52+0000 [-] Ready to accept SSH connections
```

Test de connexion depuis le Dell via Tailscale :

```bash
ssh -p 2222 root@[IP-Tailscale-du-Pi]
```

Cowrie accepte n'importe quel mot de passe et présente un environnement Linux simulé complet — prompt, commandes fonctionnelles, `/etc/passwd` avec des utilisateurs fictifs (`phil`, `root`...), hostname générique (`svr04`).

Chaque action est enregistrée en temps réel :

```bash
docker logs cowrie --follow
```

Les logs capturent : IP source, version SSH du client, fingerprint de clé, mot de passe tenté, chaque commande tapée.

---

## Ce qu'il reste à faire

Ouvrir le port 2222 sur la box pour exposer Cowrie sur Internet — c'est la dernière étape avant de recevoir du vrai trafic attaquant.

---

## Ce que j'ai appris

Un honeypot n'est pas une mesure de sécurité défensive — c'est un outil d'observation. Il ne protège rien, il renseigne. La valeur est dans ce que les attaquants révèlent de leurs méthodes une fois qu'ils pensent avoir réussi.

> **À noter :** Cowrie est une image distroless minimaliste — elle ne contient pas les outils Unix habituels (`id`, `bash`...). Le diagnostic de permissions a nécessité de passer par `docker inspect` plutôt que `docker exec`.
