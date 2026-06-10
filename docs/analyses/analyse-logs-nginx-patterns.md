# Analyse des logs Nginx : patterns de scan et investigation d'IP

> Deuxième session d'analyse — utilisation de `awk`, `sort`, et `uniq` pour identifier les IPs les plus actives et investiguer leurs comportements sur 111 000 lignes de logs réels.

**Contexte :** Raspberry Pi 5, Debian 12, Nginx reverse proxy. Logs accessibles via bind mount Docker sur l'hôte.

---

## Démarche

Lire les logs ligne par ligne ne passe pas à l'échelle sur 111 629 entrées. L'objectif de cette session : utiliser des outils Unix pour extraire des patterns sur un volume réel.

### Compter les lignes

```bash
wc -l /home/badwolf01/docker/nginx-proxy/logs/access.log
# 111629
```

### Identifier les IPs les plus actives

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -20
```

Décomposition de la commande :
- `awk '{print $1}'` — extrait le premier champ de chaque ligne (l'IP source)
- `sort` — trie les IPs pour regrouper les identiques
- `uniq -c` — compte les occurrences consécutives identiques
- `sort -rn` — retrie par nombre décroissant (`-r` = reverse, `-n` = numérique)
- `head -20` — affiche les 20 premières

Résultat :

```
9505 151.243.150.23
9002 185.177.72.58
3001 185.177.72.9
3001 185.177.72.68
3001 185.177.72.51
3001 185.177.72.24
3000 185.177.72.22
3000 185.177.72.13
2318 213.209.159.175
...
1103 82.123.95.222
```

---

## Fausse alerte : mon IP publique dans les logs

`82.123.95.222` apparaît 1103 fois. En vérifiant sur Shodan, cette IP correspond à mon propre domaine.

Investigation des requêtes :

```bash
grep "^82.123.95.222" access.log | awk '{print $7,$9}' | sort | uniq -c | sort -rn | head -10
```

Résultat : requêtes vers `/api/version`, `/_app/version.json`, `/ws/socket.io` — en boucle régulière, depuis un user-agent Chrome sur Mac, avec `https://bdwlf-cyberdeck.xyz:8443/` en referer.

**Diagnostic :** c'est moi. Ces logs datent d'avril 2026, quand j'utilisais encore Open WebUI via le port 8443. Mon propre navigateur apparaît dans mes logs comme source externe.

**Leçon :** toujours regarder la date avant d'analyser une requête. Un log de deux mois n'a pas la même signification qu'un log d'hier.

**Action corrective :** fermer le port 8443 sur la box — le service n'existe plus, la redirection est une surface d'attaque inutile.

---

## Investigation 1 — Scanner de fichiers de configuration

**IP :** `151.243.150.23` — 9505 requêtes

```bash
grep "^151.243.150.23" access.log | awk '{print $7,$9}' | sort | uniq -c | sort -rn | head -20
```

Résultat :
```
10 /.env 301
 5 /wp-config.php 301
 5 /wp-login.php.bak 301
 5 /zabbix/.env 301
 5 /zipkin/.env 301
...
```

Ce bot cherche des fichiers de configuration sensibles exposés accidentellement : `.env` (variables d'environnement, mots de passe, clés API), `wp-config.php` (configuration WordPress), fichiers `.bak` (sauvegardes oubliées).

**whois :** DEDIK SERVICES LIMITED, Londres — organisation créée en juin 2025, bloc IP assigné en février 2026. Très récente. Le nom "dedik" est une abréviation de "dedicated server", courant chez les hébergeurs utilisés pour des activités de scan.

**Vérification locale :**
```bash
find /home/badwolf01/html_file -name "*.env*" -o -name "*.bak" -o -name "wp-config*"
# Aucun résultat
```

Aucun fichier sensible exposé. Toutes les réponses sont 301 ou 404 — le bot ne trouve rien.

**Verdict : scanner automatisé de fichiers de configuration. Infrastructure suspecte et récente.**

---

## Investigation 2 — Infrastructure de scan industriel

**IP :** `185.177.72.58` — 9002 requêtes  
**Sous-réseau actif :** `185.177.72.x` — plusieurs IPs du même bloc avec 3000 requêtes chacune

```bash
grep "^185.177.72.58" access.log | awk '{print $7,$9}' | sort | uniq -c | sort -rn | head -20
```

Résultat :
```
3 /xampp/%2eenv 404
3 /www/%2eenv 404
3 /wp-includes/%2eenv 404
3 /wordpress/%2eenv 404
...
```

**Observation clé :** `%2e` est l'encodage URL du caractère `.`. Ce bot cherche `.env` mais en encodant le point pour contourner des règles de sécurité qui filtrent les requêtes vers `.env` directement. C'est plus sophistiqué qu'un scanner basique.

**whois :** FBW NETWORKS SAS, Vélizy-Villacoublay (France) — hébergeur télécom en apparence légitime. Mais le contact abuse est `bucklog@tutamail.com` — une adresse mail anonyme chiffrée. Un hébergeur sérieux utilise un contact abuse professionnel, pas une adresse anonyme.

**Shodan :** IP localisée en Espagne (divergence avec l'enregistrement français), port Kubernetes ouvert, aucune autre information.

**Hypothèse :** infrastructure de scan industriel — plusieurs bots orchestrés en conteneurs Kubernetes, ciblant des dizaines de serveurs en parallèle. Soit la société est un écran, soit l'infrastructure a été compromise et utilisée à son insu.

**Verdict : scan sophistiqué avec contournement de filtres, infrastructure probablement dédiée au scan à grande échelle.**

---

## Bilan

| IP | Requêtes | Comportement | Verdict |
|---|---|---|---|
| 82.123.95.222 | 1103 | Mon propre navigateur via WebUI | Fausse alerte — moi-même |
| 151.243.150.23 | 9505 | Scanner de fichiers `.env`, `.bak` | Suspect — organisation récente |
| 185.177.72.x | ~21000 | Scanner avec encodage URL, Kubernetes | Suspect élevé — scan industriel |

---

## Ce que j'ai appris

**Sur les outils :** `awk` + `sort` + `uniq -c` est le pipeline de base pour extraire des patterns depuis des logs bruts. Pas besoin d'un SIEM pour une première analyse.

**Sur l'analyse :** la date d'un log est aussi importante que son contenu. Un comportement identique peut être bénin (moi-même il y a deux mois) ou malveillant (scan actif aujourd'hui).

**Sur les attaquants :** les scanners professionnels encodent leurs requêtes pour contourner les filtres. `%2e` au lieu de `.` est un indicateur de sophistication — pas un script basique, un outil conçu pour éviter la détection.

> **Réflexe à retenir :** avant d'investiguer une IP, regarder la date. Avant de conclure sur un whois, croiser avec Shodan. Les deux sources se complètent et se contredisent parfois.
