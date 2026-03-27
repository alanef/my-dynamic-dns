# My Dynamic DNS

A simple bash script that updates a Cloudflare DNS A record with your current public IPv4 address. Designed to run as a cron job for dynamic DNS.

## Setup

1. Create a Cloudflare API token with **Zone > DNS > Edit** permission for your zone.

2. Find your Zone ID on the Cloudflare dashboard (domain overview page, right sidebar).

3. Make sure the A record already exists in Cloudflare DNS.

4. Add a cron job:

```bash
crontab -e
```

```
*/5 * * * * CF_API_TOKEN="your-token" CF_ZONE_ID="your-zone-id" CF_DDNS_HOSTNAME="my-host" /path/to/update-dns.sh >> /tmp/cloudflare-ddns.log 2>&1
```

## Configuration

All configuration is via environment variables:

| Variable | Required | Description |
|---|---|---|
| `CF_API_TOKEN` | Yes | Cloudflare API token with DNS edit permission |
| `CF_ZONE_ID` | Yes | Cloudflare Zone ID |
| `CF_DDNS_HOSTNAME` | No | Subdomain to update (defaults to system hostname) |

The domain is automatically fetched from Cloudflare using the Zone ID. If `CF_DDNS_HOSTNAME` is not set, the system hostname is used. The script stores the last known IP in `/tmp/cloudflare-ddns-{hostname}.ip` and only calls the Cloudflare API when the IP changes.

## License

MIT
