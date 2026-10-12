# Home network: special cases

*[🇫🇷 Version française](network.fr.md)*

[The home guide](README.md) covers the common case: a free DuckDNS subdomain and ports 80/443 forwarded by your router. This page covers the cases where that doesn't fit.

- [Your own domain at OVH (DynHost)](#your-own-domain-at-ovh-dynhost)
- [No public IPv4 (CGNAT)](#no-public-ipv4-cgnat)
- [Serving two hostnames during a migration](#serving-two-hostnames-during-a-migration)

## Your own domain at OVH (DynHost)

Already own a domain? A subdomain of it works the same way as DuckDNS and avoids a real pitfall of third-party dynamic-DNS domains: some mobile carriers and VPNs filter `*.duckdns.org` and similar by category (flagged as dynamic DNS in threat-intel lists), which can silently block visitors on those networks.

If your domain's DNS zone is managed at [OVH](https://www.ovh.com), **DynHost** is OVH's own mechanism for exactly this case (a residential IP that changes) — no need for OVH's full signed API, just an HTTP update call in the same spirit as DuckDNS's.

1. In the OVH manager, on your domain's DNS zone, create a **DynHost** record for the subdomain you want (e.g. `test.your-domain.fr`).
2. Still in the OVH manager, create a dedicated **DynHost access** (its own login/password, separate from your main OVH account credentials) scoped to that one record.
3. On the Pi, same shape as the DuckDNS script. Adapt [ddns/ovh-dynhost.sh.example](ddns/ovh-dynhost.sh.example) with your DynHost login/password and subdomain, and copy it to `~/ovh-ddns/ovh-ddns.sh`:
   ```bash
   mkdir ~/ovh-ddns && cd ~/ovh-ddns
   chmod 700 ovh-ddns.sh
   ./ovh-ddns.sh
   cat ovh-ddns.log   # should print "OK"
   ```
4. Same cron schedule as DuckDNS, pointed at `ovh-ddns.sh` instead.

DynHost only ever updates A records, never AAAA. On an IPv6-only connection, see [below](#an-ovh-domain-on-ipv6-only).

## No public IPv4 (CGNAT)

Some ISPs — in France, this is common on SFR/Red by SFR fiber lines — put residential connections behind Carrier-Grade NAT (often via DS-Lite): you get a real public IPv6 but only a private, shared IPv4, and the router's IPv4 port-forwarding menu either disappears or silently does nothing. Signs you're affected: that menu is missing/grayed out, or the connection is otherwise clearly not a real public IPv4.

Two ways out:

1. **Ask your ISP for a public IPv4 / "CGNAT rollback"** — for SFR/Red by SFR, technical support can do this on request (usually within about a week). Keeps the rest of the home guide unchanged.
2. **Go IPv6-only instead** — works immediately, no ISP ticket, and stays fully self-hosted (no third-party tunnel). The one real tradeoff: visitors on IPv4-only networks (uncommon in France — [~73% IPv6 adoption in 2026](https://www.arcep.fr/fileadmin/reprise/observatoire/ipv6/Arcep_2025_Barometer_of_the_Transition_to_IPv6.pdf) — but not zero) simply can't reach the server.

### Going IPv6-only

- Find the Pi's global IPv6 address:
  ```bash
  ip -6 addr show eth0   # the "scope global" line, not fe80::...
  ```
- In the router, look for a separate **IPv6 firewall** section (not the IPv4 NAT one) and open inbound TCP 80/443 to that address — a firewall rule, not port forwarding, since IPv6 has no NAT to traverse.
- Point DuckDNS at an **AAAA** record too, re-reading the address each run since it can change with the delegated prefix:
  ```bash
  cd ~/duckdns
  cat > duck.sh << 'SCRIPT'
  IP6=$(ip -6 addr show eth0 | grep "scope global" | awk '{print $2}' | cut -d/ -f1)
  echo url="https://www.duckdns.org/update?domains=<your-subdomain>&token=<your-token>&ip=&ipv6=${IP6}" | curl -k -o ~/duckdns/duck.log -K -
  SCRIPT
  chmod 700 duck.sh
  ./duck.sh && cat duck.log   # should print "OK"
  ```
  (the same cron entry from the home guide keeps this current — no change needed there)
- Caddy needs no changes — it listens on both address families by default.

### An OVH domain on IPv6-only

DynHost can't help here — it only updates A records, never AAAA, no matter how the request is made. Keeping an AAAA record current instead needs OVH's full signed API:

1. Open this URL while logged in to OVH (no placeholder to fill in — the query string itself requests GET/PUT/POST rights on the DNS zone):
   ```
   https://eu.api.ovh.com/createToken/?GET=/domain/zone/*&PUT=/domain/zone/*&POST=/domain/zone/*
   ```
   Give the script a name/description, confirm the rights, validate — this one page hands back all three credentials at once: **Application Key**, **Application Secret**, and **Consumer Key**. No separate "create an application" step.
2. Fill in [ddns/ovh-ipv6.mjs.example](ddns/ovh-ipv6.mjs.example) with the three keys above plus your zone/subdomain, and copy it to `~/ovh-ddns/ovh-ipv6-ddns.mjs` on the Pi. Needs only Node's own builtins — nothing to `npm install`.
3. Cron, same 5-minute cadence:
   ```
   */5 * * * * /usr/bin/node ~/ovh-ddns/ovh-ipv6-ddns.mjs >> ~/ovh-ddns/ovh-ddns.log 2>&1
   ```

(If your OVH account isn't on the EU endpoint, swap `eu.api.ovh.com` for `ca.api.ovh.com` or the US equivalent in both the script and the `createToken` URL.)

### Checking from a Windows machine

If the end-to-end check hangs/times out from a Windows machine that otherwise looks fine, check whether IPv6 is actually enabled on its network adapter before suspecting the server — it's sometimes switched off by default or by an old tweak, even when the ISP box itself has working IPv6:
```powershell
Get-NetAdapterBinding -ComponentID ms_tcpip6   # look for Enabled: False on your real adapter
Enable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6   # run as Administrator
```

## Serving two hostnames during a migration

Moving from DuckDNS to your own domain, and keeping both live for a while? The two dynamic-DNS scripts and their cron entries can run side by side. In Caddy, add one site block per hostname, same backend:

```
<your-name>.duckdns.org {
    reverse_proxy 127.0.0.1:8080
}

<your-subdomain>.your-domain.fr {
    reverse_proxy 127.0.0.1:8080
}
```

Caddy requests and renews a separate Let's Encrypt certificate per hostname automatically — no extra config needed.
