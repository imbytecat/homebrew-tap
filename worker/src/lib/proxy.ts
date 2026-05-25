import type { Context } from "hono";

export interface RedirectProxyOptions {
  cacheKey: string;
  resolve: () => Promise<string>;
  ttl: number;
}

export async function redirectProxy(c: Context, opts: RedirectProxyOptions) {
  const cache = caches.default;
  const cacheRequest = new Request(`https://homebrew-proxy.internal/${opts.cacheKey}`);

  const cached = await cache.match(cacheRequest);
  if (cached) {
    return c.redirect(await cached.text(), 302);
  }

  let url: string;
  try {
    url = await opts.resolve();
  } catch (e) {
    return c.text(`Upstream error: ${(e as Error).message}`, 502);
  }

  c.executionCtx.waitUntil(
    cache.put(
      cacheRequest,
      new Response(url, {
        headers: { "Cache-Control": `public, max-age=${opts.ttl}` },
      }),
    ),
  );

  return c.redirect(url, 302);
}
