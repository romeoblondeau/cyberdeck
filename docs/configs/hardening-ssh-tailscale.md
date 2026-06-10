# Durcissement SSH : restriction à l'interface Tailscale

> Audit du pare-feu du Cyberdeck, vérification de l'exposition réelle depuis l'extérieur, et application du principe de moindre privilège sur SSH — sans interruption d'accès.

**Contexte :** Raspberry Pi 5 sous Debian 12, accès SSH via Tailscale, pare-feu UFW + Fail2Ban.

---

## Le déclencheur

En préparant une centralisation de logs, je me suis posé une question simple : mon port SSH est-il exposé sur Internet ? Je pensais le savoir, mais je n'en avais aucune preuve. Premier indice qui m'a intrigué — Fail2Ban n'avait banni personne :

```bash
$ sudo fail2ban-client status sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
`- Actions
   |- Currently banned: 0
   `- Total banned:     0
```

Un serveur SSH réellement exposé sur Internet subit des centaines de tentatives par jour (les bots scannent le port 22 en continu). Un `Total failed: 0`, c'est anormal — et révélateur.

## Vérification couche par couche

**1. Sur quelle interface SSH écoute :**

```bash
$ sudo ss -tlnp | grep :22
LISTEN 0  128  0.0.0.0:22
LISTEN 0  128  [::]:22
```

`0.0.0.0:22` → SSH écoute sur toutes les interfaces. Joignable de partout *en théorie*, si le réseau le permet.

**2. Ce qu'autorise le pare-feu :**

```bash
$ sudo ufw status verbose
Default: deny (incoming), allow (outgoing), deny (routed)

22/tcp       ALLOW IN    Anywhere
22/tcp (v6)  ALLOW IN    Anywhere (v6)
```

UFW autorise le 22 depuis n'importe quelle source. Mais attention : ce que le pare-feu du Pi autorise ne dit rien sur ce qui lui parvient réellement depuis Internet. Entre les deux, il y a le NAT de la box.

**3. Le seul test concluant — depuis l'extérieur :**

On ne peut pas tester son exposition Internet depuis son propre réseau (risque de faux positif via NAT loopback). Test réalisé depuis un téléphone en 4G (WiFi coupé), sur l'IP publique :

```
Port 22 is closed.
```

## Diagnostic

Tout s'explique : aucune redirection de port n'est configurée sur la box. Le trafic Internet est stoppé au niveau du NAT, bien avant d'atteindre UFW ou sshd.

**Conclusion : j'étais protégé par défaut de configuration, pas par choix délibéré.** C'est une posture fragile — le jour où une redirection est ajoutée pour exposer un autre service, la règle `22 ALLOW Anywhere` devient une surface d'attaque réelle, sans intervention consciente.

## Durcissement (moindre privilège)

Objectif : SSH joignable uniquement via Tailscale, mon seul chemin d'accès réel. Tailscale expose une interface dédiée (`tailscale0`) — on restreint le 22 à cette interface.

Contrainte : la modification se fait à distance, sur le port utilisé pour la connexion en cours. Pour éviter tout lockout, ordre prudent — **ajouter la nouvelle règle, la tester, puis seulement supprimer l'ancienne.**

**Étape 1 — ajouter la règle restreinte :**

```bash
sudo ufw allow in on tailscale0 to any port 22 proto tcp
```

Deux règles coexistent désormais (ancienne + nouvelle) : aucun risque de coupure.

**Étape 2 — tester depuis une seconde session, sans fermer la première :**

```bash
ssh badwolf01@bdwlf-cyberdeck
```

Connexion établie → le chemin Tailscale fonctionne avec la nouvelle règle.

**Étape 3 — supprimer l'ancienne règle trop permissive :**

```bash
sudo ufw delete allow 22/tcp
# Rule deleted
# Rule deleted (v6)   ← v4 et v6 retirées ensemble
```

**Étape 4 — vérification finale :**

```bash
$ sudo ufw status verbose
22/tcp on tailscale0       ALLOW IN    Anywhere
22/tcp (v6) on tailscale0  ALLOW IN    Anywhere (v6)
```

Plus aucune règle `22/tcp Anywhere` sans restriction d'interface. Le `on tailscale0` est la vraie limitation : un paquet venu d'Internet n'arrive jamais par cette interface — il atteindrait `eth0`/`wlan0`, où plus aucune règle ne l'autorise.

> Remarque sur la lecture d'UFW : la colonne `From` affiche toujours `Anywhere`, ce qui peut induire en erreur. La restriction est portée par la colonne `To` (`22/tcp on tailscale0`), c'est-à-dire l'interface d'entrée — et non l'IP source.

## À retenir

- **Ne pas supposer son exposition — la tester, et depuis l'extérieur.** Un test depuis son propre réseau peut mentir.
- **« Le pare-feu autorise » ≠ « c'est joignable depuis Internet ».** Il y a plusieurs couches (NAT → pare-feu → service), chacune devant être correcte indépendamment (défense en profondeur).
- **Modification de pare-feu à distance :** toujours ajouter avant de supprimer, et conserver une session de secours ouverte.
