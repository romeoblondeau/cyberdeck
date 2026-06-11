# Cowrie — Premières 24h : reconnaissance, brute force et post-intrusion

> Analyse du trafic capturé dans les premières 24 heures d'exposition du honeypot SSH. Trois phases d'attaque observées, trois pays d'origine, une tentative de nettoyage de traces.

**Contexte :** Honeypot Cowrie exposé sur le port 2222, Raspberry Pi 5, Debian 12. Port ouvert le 10 juin 2026 au soir.

---

## Ce qui m'a surpris

Le honeypot a fonctionné immédiatement — les premiers scans sont arrivés dans l'heure suivant l'ouverture du port. Ce qui m'a le plus frappé : les attaquants restent très peu de temps, testent rapidement, et passent à autre chose. C'est entièrement automatisé.

En moins de 24h : connexions depuis la Chine, la France, et les Pays-Bas. Internet est petit.

---

## Phase 1 — Reconnaissance (keyscan)

```
[HoneyPotSSHTransport,37,51.158.205.203] Remote SSH version: SSH-2.0-OpenSSH-keyscan
[HoneyPotSSHTransport,37,51.158.205.203] Connection lost after 0.1 seconds
```

Première étape avant tout brute force : vérifier que le serveur SSH existe et récupérer sa clé publique. L'outil `ssh-keyscan` se connecte, collecte les informations, et se déconnecte immédiatement — pas de tentative d'authentification.

`51.158.205.203` — VPS chez **Scaleway** (Amsterdam). 5 connexions simultanées depuis la même IP, toutes en moins d'une seconde. Scan industriel.

---

## Phase 2 — Brute force

```
[HoneyPotSSHTransport,44,130.12.180.51] login attempt [b'admin'/b'admin'] succeeded
[HoneyPotSSHTransport,47,45.148.10.121] login attempt [b'admin'/b'admin'] succeeded
```

Credential testé : `admin/admin` — le mot de passe par défaut de millions d'appareils mal configurés (routeurs, caméras IP, serveurs cheap). C'est le premier test systématique parce que ça fonctionne encore sur énormément de machines.

Cowrie accepte n'importe quel mot de passe — les attaquants pensent avoir réussi.

---

## Phase 3 — Post-intrusion : tentative de nettoyage

```
[HoneyPotSSHTransport,12,130.12.180.51] SFTP openFile: b'clean.sh'
Request failed with unknown error
```

Après connexion, `130.12.180.51` tente de déposer un fichier `clean.sh` via SFTP. Un fichier `.sh` est un script shell Linux — une série de commandes exécutables.

`clean.sh` — le nom est explicite : effacer les traces. Supprimer les logs, vider l'historique des commandes, éliminer toute preuve du passage de l'attaquant. Technique post-intrusion classique.

Cowrie a bloqué le transfert — le filesystem simulé n'a pas pu créer le fichier. L'attaquant n'a pas pu nettoyer.

**C'est exactement pour ça que les logs ne doivent jamais être stockés uniquement sur la machine surveillée.** Si `clean.sh` avait fonctionné sur un vrai serveur, les traces locales auraient disparu. Un système de centralisation des logs (Loki, SIEM) rend les logs inaltérables depuis la machine compromise.

---

## Comportements annexes

**Scan HTTP sur port SSH :**
```
Remote SSH version: GET /favicon.ico HTTP/1.1
Bad protocol version identification
```
Des bots envoient des requêtes HTTP sur le port 2222 sans savoir ce qui écoute. Scan aveugle sur tous les ports — pas ciblé.

**Connexion longue sans activité :**
`180.76.172.156` (Baidu, Chine) — connecté 120 secondes sans rien faire. `libssh2_1.11.1` — bibliothèque SSH utilisée dans des scripts automatisés. Probablement en attente d'instructions d'un serveur de commande distant.

---

## IPs observées

| IP | Hébergeur | Pays | Comportement |
|---|---|---|---|
| 51.158.205.203 | Scaleway | Pays-Bas | Keyscan — reconnaissance |
| 130.12.180.51 | — | — | Brute force + tentative SFTP |
| 45.148.10.121 | — | — | Brute force `admin/admin` |
| 180.76.172.156 | Baidu | Chine | Connexion longue inactive |
| 165.232.126.52 | — | — | Scan HTTP sur port SSH |

---

## Les trois phases d'une attaque observées en 24h

1. **Reconnaissance** — keyscan, vérification que le port répond
2. **Brute force** — credentials par défaut (`admin/admin`)
3. **Post-intrusion** — tentative de dépôt de script de nettoyage

Ce cycle complet en moins de 24h confirme que l'automatisation est totale. Personne ne fait ça à la main.

---

## Ce que j'ai appris

Un honeypot ne protège rien — il observe. Sa valeur est dans ce qu'il révèle des méthodes des attaquants. En 24h : trois phases d'attaque documentées, cinq IPs de trois pays différents, et une compréhension concrète de pourquoi la centralisation des logs est une mesure de sécurité fondamentale.

> **Réflexe à retenir :** si les logs sont sur la machine compromise, un attaquant peut les effacer. Les logs doivent toujours être envoyés vers un système externe en temps réel.
