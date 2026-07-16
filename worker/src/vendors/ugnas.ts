import { Hono } from "hono";
import { redirectProxy, USER_AGENT } from "../lib/proxy";

const LIST_API = "https://api-zh.ugnas.com/api/system/v3/sa/apk";
const TEMP_LINK_API = "https://api-zh.ugnas.com/api/system/v1/ua/temp/link";
const APP_NO = "com.ugreenNasPro.mac";
const ARM_CLIENT_BIT = 3;
const CACHE_TTL_SECONDS = 120;
const UPSTREAM_TIMEOUT_MS = 15_000;

interface UgnasTempLinkResponse {
  msg?: string;
  data?: { linkData?: { tempUrl?: string } };
}

interface UgnasListItem {
  appNo?: string;
  clientBit?: string | number;
  id?: string | number;
  verName?: string;
}

interface UgnasListResponse {
  data?: { appSoftVers?: UgnasListItem[] };
}

export async function resolveById(id: string): Promise<string> {
  const res = await fetch(`${TEMP_LINK_API}?appType=client&id=${encodeURIComponent(id)}`, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`UGREEN TEMP_LINK HTTP ${res.status} for id=${id}`);

  const data = (await res.json()) as UgnasTempLinkResponse;
  const tempUrl = data.data?.linkData?.tempUrl;
  if (!tempUrl) throw new Error(`UGREEN TEMP_LINK for id=${id}: ${data.msg ?? "no tempUrl"}`);
  return tempUrl;
}

export async function resolveByVersion(version: string): Promise<string> {
  const listRes = await fetch(LIST_API, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
  });
  if (!listRes.ok) throw new Error(`UGREEN LIST API HTTP ${listRes.status}`);

  const listData = (await listRes.json()) as UgnasListResponse;
  const item = listData.data?.appSoftVers?.find(
    (candidate) => candidate.appNo === APP_NO && Number(candidate.clientBit) === ARM_CLIENT_BIT,
  );
  if (!item) throw new Error("UGREEN LIST API: no Apple Silicon macOS build found");

  const itemVersion = item.verName?.replace(/^v/i, "");
  if (itemVersion !== version) {
    throw new Error(
      `UGREEN LIST API: requested version ${version} no longer current (upstream now ${itemVersion ?? "<missing>"}). ` +
        "Run `brew update` to refresh the tap; the cask may also need a fresh bump.",
    );
  }

  const id = item.id;
  if (id == null) throw new Error("UGREEN LIST API: missing id");

  return resolveById(String(id));
}

export const ugnas = new Hono();

ugnas.get("/dl", async (c) => {
  const v = c.req.query("v");
  if (!v) return c.text("Missing required query: v", 400);
  if (!/^\d+(?:\.\d+)*$/.test(v)) return c.text("Invalid v (must be a dotted version)", 400);

  const id = c.req.query("id");
  if (id !== undefined && !/^\d+$/.test(id)) {
    return c.text("Invalid id (must be digits)", 400);
  }

  return redirectProxy(c, {
    cacheKey: id ? `ugnas/id/${id}` : `ugnas/v/${v}`,
    resolve: () => (id ? resolveById(id) : resolveByVersion(v)),
    ttl: CACHE_TTL_SECONDS,
  });
});
