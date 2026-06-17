# Script d'investigation IP — investigate.sh

## Objectif

Automatiser l'investigation d'une IP suspecte détectée dans les logs Nginx ou Cowrie, sans avoir à interroger manuellement chaque source.

---

## Utilisation

```bash
./investigate.sh <IP>
```

Exemple :

```bash
./investigate.sh 87.251.64.176
```

---

## Ce que le script retourne

### WHOIS
- Provenance de l'IP (pays, ville)
- Organisation ou individu propriétaire
- Plage réseau associée (CIDR)

### AbuseIPDB
- Score de dangerosité de 0 à 100
- Nombre total de signalements
- Nombre d'utilisateurs distincts ayant signalé l'IP
- Date du dernier signalement

### Shodan
- Lien direct vers la fiche de l'IP pour investigation manuelle approfondie (ports ouverts, services, bannières)

---

## Exemple de résultat

```
=== AbuseIPDB ===
{
  "ip": "87.251.64.176",
  "pays": "PL",
  "isp": "ISAEV Igor",
  "domaine": "novahost.kz",
  "score": 100,
  "signalements": 8089,
  "utilisateurs": 101,
  "derniere_activite": "2026-06-17T12:05:03+00:00"
}

=== WHOIS ===
descr:          Isaev Igor Maratovich
netname:        ISAEV
country:        PL
address:        Kazakhstan, Almaty region, city of Almaty, Zhibek Zholy street 100
route:          87.251.64.0/24

=== SHODAN ===
https://www.shodan.io/host/87.251.64.176
```

---

## Stack technique

- **bash** — langage du script
- **curl** — appels HTTP vers l'API AbuseIPDB
- **jq** — parsing et formatage du JSON
- **whois** — interrogation des registres réseau
- **AbuseIPDB API** — base collaborative de réputation IP

---

## Sécurité

La clé API AbuseIPDB est stockée dans `~/.env_scripts` avec des permissions `600` (lecture/écriture propriétaire uniquement) et chargée via `source` au lancement du script. Ce fichier est exclu du repo GitHub via `.gitignore`.

---

## Permissions Linux

Deux commandes `chmod` sont utilisées dans ce projet.

**`chmod 600 ~/.env_scripts`** — sécurise le fichier de clé API.

Les permissions Linux se lisent en trois chiffres : **propriétaire / groupe / autres**. Chaque chiffre est la somme de :
- **4** = lecture (r)
- **2** = écriture (w)
- **1** = exécution (x)

`600` = 4+2 / 0 / 0 → lecture + écriture pour le propriétaire uniquement, rien pour les autres. Un fichier `.env` n'a pas besoin d'être exécuté, juste lu.

**`chmod +x ~/scripts/investigate.sh`** — rend le script exécutable.

`+x` est la notation symbolique pour ajouter le droit d'exécution. L'équivalent en chiffres serait `755` :
- **7** = 4+2+1 = lecture + écriture + exécution pour le propriétaire
- **5** = 4+1 = lecture + exécution pour le groupe et les autres

Sans cette étape, bash refuse de lancer le fichier directement avec `./investigate.sh`.

---

## Notes

Les champs WHOIS varient selon les registres (ARIN, RIPE, APNIC). Les serveurs d'Europe de l'Est et d'Asie Centrale utilisent souvent le champ `descr` au lieu de `OrgName` — le grep avec `-iE` couvre les deux cas.
