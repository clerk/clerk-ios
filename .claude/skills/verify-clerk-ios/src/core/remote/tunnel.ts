/**
 * The one place that names the tunnel. The runner runs `command`, the driver sends the bearer only to hosts under
 * `allowedSuffix`, and a cloud environment's allowed-domains list needs `allowedHost`.
 */
export const TUNNEL = {
  allowedHost: '*.trycloudflare.com',
  allowedSuffix: '.trycloudflare.com',
  /** A name under the wildcard that always resolves, for reachability checks when no session is up. */
  probeHost: 'api.trycloudflare.com',
  binary: 'cloudflared',
  command: (port: number): readonly string[] => ['tunnel', '--no-autoupdate', '--url', `http://127.0.0.1:${port}`],
  hostPattern: /https:\/\/([a-z0-9-]+\.trycloudflare\.com)/,
} as const;

export function isTunnelHost(host: string): boolean {
  return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(host) && host.endsWith(TUNNEL.allowedSuffix);
}
