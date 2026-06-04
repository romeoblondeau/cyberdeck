# Réduction de surface d'attaque : retrait des services exposés

> Audit des services exposés publiquement, décision de retrait, et remplacement par une page statique — sans interruption du domaine.

**Contexte :** Raspberry Pi 5, Debian 12, Nginx reverse proxy, domaine public `bdwlf-cyberdeck.xyz`.

---

## Le déclencheur

En analysant mes logs Nginx, j'ai constaté que mon serveur était activement scanné depuis Internet — bots automatisés, indexeurs comme Censys. Ça m'a poussé à reposer une question simple :

> Est-ce que chaque service exposé publiquement a vraiment besoin de l'être ?

---

## Ce qui était exposé

| Service | Chemin | Protection |
|---|---|---|
| Dashy | `/` | Aucune |
| Filebrowser | `/cloud/` | Mot de passe |

---

## Pourquoi c'était un problème

**Filebrowser** donnait accès à mes fichiers personnels depuis Internet. Un mot de passe, c'est une surface d'attaque — susceptible d'être attaqué par brute force. Le principe de moindre exposition s'impose : un service qui n'a pas besoin d'être public ne doit pas l'être.

**Dashy** n'était plus utilisé. Il avait rempli son rôle — comprendre Docker et le YAML — mais le garder exposé sans usage réel, c'est de la surface d'attaque gratuite.

---

## Ce que j'ai fait

**1. Récupérer les données avant toute suppression**

Sauvegarde des fichiers Filebrowser avant de toucher quoi que ce soit. Toujours sécuriser les données avant de démanteler un service.

**2. Modifier la conf Nginx**

Suppression des blocs `server` pointant vers Dashy et Filebrowser dans `conf.d/02_main.conf`, remplacés par un bloc servant une page HTML statique :

```nginx
location / {
    root  /home/badwolf01/html_file;
    index web_page.html;
}
```

**3. Monter le dossier dans le conteneur Nginx**

Nginx tourne dans Docker — il ne voit que ce qui lui est monté via `volumes`. Ajout dans `docker-compose.yml` :

```yaml
- /home/badwolf01/html_file:/home/badwolf01/html_file
```

Erreur rencontrée : utiliser un chemin relatif (`./home/...`) au lieu du chemin absolu — le conteneur cherchait le dossier à l'intérieur du contexte Docker Compose, pas sur le système hôte.

**4. Vérifier et recharger Nginx**

```bash
docker exec nginx-proxy nginx -t        # Vérification syntaxe
docker exec nginx-proxy nginx -s reload # Rechargement sans coupure
```

**5. Supprimer les conteneurs**

```bash
cd ~/docker/dashy && docker compose down
cd ~/docker/filebrowser && docker compose down
cd ~/docker/ollama && docker compose down
```

Puis suppression des dossiers devenus inutiles.

---

## Ce que j'ai appris

Un fichier HTML servi directement par Nginx est plus sûr et plus léger qu'un service Docker : pas d'image à maintenir, pas de processus, pas de socket réseau supplémentaire.

Chaque conteneur retiré, c'est une surface d'attaque en moins.

> **`nginx -s reload`** recharge la configuration sans couper les connexions en cours — contrairement à `restart` qui interrompt brièvement le service. Toujours préférer `reload` en production.

---

## Résultat

- Dashy ✗ supprimé
- Filebrowser ✗ supprimé  
- Ollama/WebUI ✗ supprimé
- Page statique ✓ déployée sur `bdwlf-cyberdeck.xyz`
- Surface d'attaque : réduite
