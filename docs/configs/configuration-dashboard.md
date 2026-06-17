# Dashboard Grafana — Visualisation des logs

## Objectif

Construire un dashboard SOC dans Grafana pour visualiser en temps réel les logs Nginx et Cowrie centralisés dans Loki.

---

## Panels créés

### Nginx — Logs bruts
Affichage du flux de logs Nginx en temps réel.

```
{job="varlogs"}
```

### Nginx — Top IPs
Table des IPs qui frappent le plus le serveur web, classées par nombre de requêtes décroissant.

```
sum by (remote_addr) (count_over_time({job="varlogs"} | pattern `<remote_addr> - -` [6h]))
```

### Cowrie — Logs bruts
Affichage du flux de logs du honeypot SSH en temps réel.

```
{container="/cowrie"}
```

### Cowrie — Top IPs attaquantes
Table des IPs qui tentent de se connecter au honeypot, classées par nombre de tentatives.

```
sum by (src_ip) (count_over_time({container="/cowrie"} | pattern `<_> [HoneyPotSSHTransport,<_>,<src_ip>]` | src_ip != "" [6h]))
```

---

## Pattern LogQL

La clé pour extraire des champs depuis des logs en texte brut c'est `| pattern`. La syntaxe : décrire le contexte autour du champ voulu, avec `<nom_champ>` pour capturer et `<_>` pour ignorer.

Exemple Cowrie :
```
`<_> [HoneyPotSSHTransport,<_>,<src_ip>]`
```

- `<_>` ignore le timestamp
- `<_>` ignore le numéro de session
- `<src_ip>` capture l'IP source

---

## Transformations Grafana

Pour les panels Table avec agrégation, deux transformations sont nécessaires :

1. **Reduce** — agrège les valeurs par série (une ligne par IP)
2. **Sort by** en ordre décroissant — classe par volume de requêtes
