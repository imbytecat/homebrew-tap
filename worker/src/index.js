const API_BASE = "https://api-zh.ugnas.com/api/system/v1/ua/temp/link";
const CACHE_TTL = 300;

const ALLOWED_IDS = new Set([
  "515",
  "516",
  "514",
  "517",
  "502",
]);

async function resolveTempUrl(id) {
  const apiRes = await fetch(`${API_BASE}?appType=client&id=${id}`, {
    headers: {
      "User-Agent": "ugnas-proxy/1.0 (+https://github.com/imbytecat/homebrew-tap)",
      "Accept": "application/json",
    },
  });
  if (!apiRes.ok) {
    throw new Error(`UGREEN API HTTP ${apiRes.status}`);
  }
  const data = await apiRes.json();
  const tempUrl = data?.data?.linkData?.tempUrl;
  if (!tempUrl) {
    throw new Error(`UGREEN API: ${data?.msg ?? "no tempUrl"}`);
  }
  return tempUrl;
}

export default {
  async fetch(req, _env, ctx) {
    const url = new URL(req.url);

    if (url.pathname === "/") {
      return new Response(
        "UGREEN NAS signed-URL proxy.\nGET /dl?id=<appId>\n" +
          "See https://github.com/imbytecat/homebrew-tap for allowed ids.\n",
        { headers: { "Content-Type": "text/plain; charset=utf-8" } }
      );
    }

    if (url.pathname !== "/dl") {
      return new Response("Not Found", { status: 404 });
    }

    const id = url.searchParams.get("id");
    if (!id || !ALLOWED_IDS.has(id)) {
      return new Response(`Invalid or unknown id: ${id ?? "<missing>"}`, { status: 400 });
    }

    const cache = caches.default;
    const cacheKey = new Request(`https://ugnas-proxy.internal/dl/${id}`);

    const cached = await cache.match(cacheKey);
    if (cached) {
      const tempUrl = await cached.text();
      return Response.redirect(tempUrl, 302);
    }

    let tempUrl;
    try {
      tempUrl = await resolveTempUrl(id);
    } catch (e) {
      return new Response(`Upstream error: ${e.message}`, { status: 502 });
    }

    ctx.waitUntil(
      cache.put(
        cacheKey,
        new Response(tempUrl, {
          headers: { "Cache-Control": `public, max-age=${CACHE_TTL}` },
        })
      )
    );

    return Response.redirect(tempUrl, 302);
  },
};
