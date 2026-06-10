# Lecture des logs Nginx : reconnaître le bruit du signal

> Première session d'analyse de logs en conditions réelles — identification de comportements suspects sur le trafic entrant, sans outil supplémentaire.

**Contexte :** Raspberry Pi 5, Debian 12, Nginx reverse proxy, domaine public `bdwlf-cyberdeck.xyz`. Logs accessibles directement sur l'hôte via bind mount Docker.

---

## Démarche

Pas d'outil de centralisation, pas de dashboard. Juste `tail -f` sur le fichier d'accès Nginx et une lecture méthodique ligne par ligne.

```bash
tail -f /home/badwolf01/docker/nginx-proxy/logs/access.log
```

L'objectif : apprendre à lire un log comme un analyste — distinguer le bruit du signal, identifier les intentions derrière les requêtes.

---

## Ce que j'ai trouvé

### 1. Crawler qui s'annonce honnêtement — Nokia GenomeCrawler

```
216.180.246.25 - - "GET / HTTP/1.0" 301 - "Mozilla/5.0 (compatible; GenomeCrawlerd/1.0; +https://www.nokia.com/genomecrawler)"
```

User-agent explicite, URL de documentation dans l'identifiant. Ce crawler indexe le web publiquement et s'annonce pour ce qu'il est. Pas malveillant — mais ça confirme que mon domaine est indexé sur Internet.

**Signal : faible. Comportement transparent.**

---

### 2. Bot déguisé en iPhone — user-agent falsifié

```
43.164.131.148 - - "GET / HTTP/1.1" 301 -  "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 ...)"
43.164.131.148 - - "GET / HTTP/1.1" 200 10307 "http://bdwlf-cyberdeck.xyz" "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 ...)"
```

iOS 13.2.3 date de 2019. En 2026, un vrai iPhone sous cette version est hautement improbable. C'est un user-agent falsifié — un bot qui se déguise en navigateur mobile pour passer inaperçu.

Comportement notable : le bot suit la redirection 301 (HTTP → HTTPS) avant d'obtenir un 200. Il se comporte comme un vrai navigateur, ce qui le rend plus difficile à détecter par des règles simples.

**Signal : modéré. Bot sophistiqué qui imite un navigateur.**

---

### 3. Handshake TLS sur le port 80 — scan automatisé brut

```
216.180.246.25 - - "\x16\x03\x01\x00\xFD\x01..." 400 157 "-" "-"
```

`\x16\x03\x01` sont les premiers octets d'une négociation TLS/SSL en hexadécimal. Ce bot a envoyé une connexion HTTPS sur le port 80, là où Nginx attend du HTTP texte. Résultat : erreur 400 — Nginx ne comprend pas ce qu'on lui envoie.

Nginx n'est pas vulnérable ici — c'est une incompatibilité de protocole. Ce type de scan vise des serveurs mal configurés qui écouteraient HTTPS sur le port 80.

**Signal : faible individuellement, mais révélateur d'un scan automatisé non ciblé.**

---

### 4. Requête nue sans identité — VPS jetable suspect

```
45.205.1.73 - - "GET / HTTP/1.1" 400 157 "-" "-" "-"
```

Pas de user-agent, pas de referer. Un vrai navigateur s'identifie toujours. Investigation via `whois` et Shodan :

```bash
whois 45.205.1.73
```

- **Bloc IP :** VPSVAULTHOST_LTD, enregistré au Brésil
- **Localisation physique (Shodan) :** Cape Town, Afrique du Sud
- **Contact abuse :** aucun enregistré — `% No abuse contact registered`
- **Services exposés :** ports 22 et 80, Ubuntu, Nginx

Profil classique d'un VPS loué ou compromis utilisé comme machine de rebond pour du scan. L'absence de contact abuse signifie qu'il n'y a personne à contacter en cas d'activité malveillante.

**Signal : élevé. Infrastructure jetable, comportement opaque.**

---

### 5. Requête PROPFIND WebDAV — reconnaissance de partage de fichiers

```
46.151.178.13 - - "PROPFIND / HTTP/1.1" 405 157 "http://82.123.95.222:443/" "-"
```

`PROPFIND` est une méthode HTTP du protocole WebDAV — une extension pour gérer des fichiers à distance via le web. Ce bot teste si mon serveur expose un partage WebDAV (fichiers, calendriers, contacts).

Réponse : 405 Method Not Allowed. WebDAV n'est pas installé sur le Pi — la requête échoue non pas parce que Nginx bloque activement, mais parce que le protocole n'existe pas.

**Observation notable :** le champ referer contient `http://82.123.95.222:443/`. En vérifiant sur Shodan, cette IP correspond à l'IP publique de mon propre serveur. Le bot a fait une requête vers moi en prétendant *venir de moi* — technique classique pour brouiller les pistes ou tester si le serveur se répond à lui-même.

**Signal : modéré. Reconnaissance ciblée sur un protocole spécifique.**

---

## Bilan

Sur 10 lignes de logs, cinq comportements distincts identifiés :

| IP | Comportement | Verdict |
|---|---|---|
| 216.180.246.25 | Nokia GenomeCrawler | Indexeur légitime |
| 43.164.131.148 | Bot déguisé en iPhone iOS 13 | Scan sophistiqué |
| 216.180.246.25 | TLS handshake sur port 80 | Scan automatisé brut |
| 45.205.1.73 | Requête nue, VPS sans contact abuse | Suspect élevé |
| 46.151.178.13 | PROPFIND WebDAV, referer = mon IP | Reconnaissance ciblée |

---

## Ce que j'ai appris

Lire des logs bruts, c'est apprendre à distinguer l'intention derrière la requête. Un code HTTP ne suffit pas — il faut croiser le user-agent, l'IP source, la méthode, le referer, et le comportement dans le temps.

Les outils utilisés : `tail -f`, `whois`, Shodan. Aucune installation supplémentaire.

> **Réflexe à retenir :** un user-agent inhabituel ou absent n'est jamais anodin. C'est souvent le premier signal d'un comportement automatisé.
