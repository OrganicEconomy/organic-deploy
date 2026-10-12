# Réseau domestique : cas particuliers

*[🇬🇧 English version](network.md)*

[Le guide maison](README.fr.md) couvre le cas courant : un sous-domaine DuckDNS gratuit et les ports 80/443 redirigés par ton routeur. Cette page couvre les cas où ça ne convient pas.

- [Un sous-domaine de ton domaine chez OVH (DynHost)](#un-sous-domaine-de-ton-domaine-chez-ovh-dynhost)
- [Pas d'IPv4 publique (CGNAT)](#pas-dipv4-publique-cgnat)
- [Servir deux noms d'hôte pendant une migration](#servir-deux-noms-dhôte-pendant-une-migration)

## Un sous-domaine de ton domaine chez OVH (DynHost)

Tu as déjà un nom de domaine ? Un sous-domaine marche comme DuckDNS, et évite un vrai écueil des domaines en dynamic DNS tiers : certains opérateurs mobiles et VPN filtrent `*.duckdns.org` et équivalents par catégorie (classés "dynamic DNS" dans des listes de threat-intel), ce qui peut bloquer silencieusement des visiteurs sur ces réseaux.

Si la zone DNS de ton domaine est gérée chez [OVH](https://www.ovh.com), **DynHost** est le mécanisme d'OVH pour exactement ce cas (une IP résidentielle qui change) — pas besoin de la pleine API signée d'OVH, juste un appel HTTP de mise à jour dans le même esprit que DuckDNS.

1. Dans le manager OVH, sur la zone DNS de ton domaine, créer un enregistrement **DynHost** pour le sous-domaine voulu (ex. `test.ton-domaine.fr`).
2. Toujours dans le manager OVH, créer un **accès DynHost** dédié (son propre login/mot de passe, distinct de tes identifiants OVH principaux), limité à cet enregistrement.
3. Sur le Pi, même principe que le script DuckDNS. Adapter [ddns/ovh-dynhost.sh.example](ddns/ovh-dynhost.sh.example) avec ton login/mot de passe DynHost et ton sous-domaine, puis le copier vers `~/ovh-ddns/ovh-ddns.sh` :
   ```bash
   mkdir ~/ovh-ddns && cd ~/ovh-ddns
   chmod 700 ovh-ddns.sh
   ./ovh-ddns.sh
   cat ovh-ddns.log   # doit afficher "OK"
   ```
4. Même planification cron que DuckDNS, pointée vers `ovh-ddns.sh` à la place.

DynHost ne met à jour que les enregistrements A, jamais les AAAA. Sur une connexion en IPv6 seule, voir [plus bas](#un-domaine-ovh-en-ipv6-seule).

## Pas d'IPv4 publique (CGNAT)

Certains FAI — en France, c'est courant sur les lignes fibre SFR/Red by SFR — placent les connexions résidentielles derrière un Carrier-Grade NAT (souvent via DS-Lite) : tu gardes une vraie IPv6 publique, mais ton IPv4 devient privée/partagée, et le menu de redirection de port IPv4 du routeur disparaît ou ne fait plus rien silencieusement. Signes que tu es concerné : ce menu est absent/grisé, ou la connexion n'est visiblement pas une vraie IPv4 publique.

Deux issues possibles :

1. **Demander à ton FAI une IPv4 publique / un "rollback CGNAT"** — chez SFR/Red by SFR, le support technique peut le faire sur demande (généralement sous environ une semaine). Garde le reste du guide maison inchangé.
2. **Passer en IPv6 uniquement** — fonctionne immédiatement, pas de ticket FAI à ouvrir, et reste entièrement auto-hébergé (pas de tunnel tiers). Le vrai compromis : les visiteurs sur des réseaux strictement IPv4 (rare en France — [~73 % d'adoption IPv6 en 2026](https://www.arcep.fr/fileadmin/reprise/observatoire/ipv6/Arcep_2025_Barometer_of_the_Transition_to_IPv6.pdf) — mais pas nul) ne pourront tout simplement pas joindre le serveur.

### Passer en IPv6 seule

- Trouver l'adresse IPv6 globale du Pi :
  ```bash
  ip -6 addr show eth0   # la ligne "scope global", pas fe80::...
  ```
- Dans le routeur, chercher une section **pare-feu IPv6** séparée (pas celle du NAT IPv4) et ouvrir l'entrant TCP 80/443 vers cette adresse — une règle de pare-feu, pas une redirection, puisque l'IPv6 n'a pas de NAT à traverser.
- Pointer aussi DuckDNS vers un enregistrement **AAAA**, en relisant l'adresse à chaque exécution puisqu'elle peut changer avec le préfixe délégué :
  ```bash
  cd ~/duckdns
  cat > duck.sh << 'SCRIPT'
  IP6=$(ip -6 addr show eth0 | grep "scope global" | awk '{print $2}' | cut -d/ -f1)
  echo url="https://www.duckdns.org/update?domains=<ton-sous-domaine>&token=<ton-token>&ip=&ipv6=${IP6}" | curl -k -o ~/duckdns/duck.log -K -
  SCRIPT
  chmod 700 duck.sh
  ./duck.sh && cat duck.log   # doit afficher "OK"
  ```
  (le même cron du guide maison garde ça à jour — rien à changer là-bas)
- Caddy n'a rien à changer — il écoute déjà sur les deux familles d'adresses par défaut.

### Un domaine OVH en IPv6 seule

DynHost ne peut rien faire ici — il ne met à jour que les A, jamais les AAAA, quelle que soit la façon de l'appeler. Garder un AAAA à jour demande la pleine API signée d'OVH :

1. Ouvrir cette URL en étant connecté à OVH (rien à remplacer — la chaîne de requête est elle-même la demande de droits GET/PUT/POST sur la zone DNS) :
   ```
   https://eu.api.ovh.com/createToken/?GET=/domain/zone/*&PUT=/domain/zone/*&POST=/domain/zone/*
   ```
   Donner un nom/une description au script, confirmer les droits, valider — cette seule page renvoie les trois identifiants d'un coup : **Application Key**, **Application Secret**, et **Consumer Key**. Pas d'étape séparée de "création d'application".
2. Remplir [ddns/ovh-ipv6.mjs.example](ddns/ovh-ipv6.mjs.example) avec ces trois clés plus ta zone/sous-domaine, et le copier vers `~/ovh-ddns/ovh-ipv6-ddns.mjs` sur le Pi. Ne nécessite que les modules natifs de Node — rien à installer via `npm`.
3. Cron, même cadence de 5 minutes :
   ```
   */5 * * * * /usr/bin/node ~/ovh-ddns/ovh-ipv6-ddns.mjs >> ~/ovh-ddns/ovh-ddns.log 2>&1
   ```

(Si ton compte OVH n'est pas sur l'endpoint EU, remplacer `eu.api.ovh.com` par `ca.api.ovh.com` ou l'équivalent US, dans le script comme dans l'URL `createToken`.)

### Vérifier depuis une machine Windows

Si la vérification de bout en bout reste bloquée/expire depuis une machine Windows qui semble pourtant normale, vérifie d'abord que l'IPv6 est bien activée sur son adaptateur réseau avant de suspecter le serveur — elle est parfois désactivée par défaut ou par une vieille manipulation, même quand la box du FAI a bien l'IPv6 qui fonctionne :
```powershell
Get-NetAdapterBinding -ComponentID ms_tcpip6   # repère Enabled: False sur ton adaptateur réel
Enable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6   # à lancer en administrateur
```

## Servir deux noms d'hôte pendant une migration

Tu passes de DuckDNS à ton propre domaine, en gardant les deux actifs un moment ? Les deux scripts de DNS dynamique et leurs entrées cron peuvent tourner en parallèle. Dans Caddy, ajouter un bloc de site par nom d'hôte, même backend :

```
<ton-nom>.duckdns.org {
    reverse_proxy 127.0.0.1:8080
}

<ton-sous-domaine>.ton-domaine.fr {
    reverse_proxy 127.0.0.1:8080
}
```

Caddy demande et renouvelle un certificat Let's Encrypt séparé pour chaque nom d'hôte, automatiquement — rien d'autre à configurer.
