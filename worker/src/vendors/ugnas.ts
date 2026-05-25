import { Hono } from "hono";
import { redirectProxy } from "../lib/proxy";

const API_BASE = "https://api-zh.ugnas.com/api/system/v1/ua/temp/link";

const ALLOWED_IDS = new Set([
  "515",
  "516",
  "514",
  "517",
  "502",
]);

interface UgnasResponse {
  code?: number;
  msg?: string;
  data?: { linkData?: { tempUrl?: string } };
}

async function fetchUgnasTempUrl(id: string): Promise<string> {
  const res = await fetch(`${API_BASE}?appType=client&id=${id}`, {
    headers: {
      "User-Agent": "homebrew-proxy/1.0 (+https://github.com/imbytecat/homebrew-tap)",
      Accept: "application/json",
    },
  });
  if (!res.ok) throw new Error(`UGREEN API HTTP ${res.status}`);

  const data = (await res.json()) as UgnasResponse;
  const tempUrl = data.data?.linkData?.tempUrl;
  if (!tempUrl) {
    throw new Error(`UGREEN API: ${data.msg ?? "no tempUrl"}`);
  }
  return tempUrl;
}

export const ugnas = new Hono();

ugnas.get("/dl", (c) => {
  const id = c.req.query("id");
  if (!id || !ALLOWED_IDS.has(id)) {
    return c.text(`Invalid or unknown id: ${id ?? "<missing>"}`, 400);
  }

  return redirectProxy(c, {
    cacheKey: `ugnas/${id}`,
    resolve: () => fetchUgnasTempUrl(id),
    ttl: 300,
  });
});
