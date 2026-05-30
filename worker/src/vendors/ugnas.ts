import { Hono } from "hono";
import { redirectProxy, USER_AGENT } from "../lib/proxy";

const LIST_API = "https://api-zh.ugnas.com/api/system/v3/sa/apk";
const TEMP_LINK_API = "https://api-zh.ugnas.com/api/system/v1/ua/temp/link";

interface UgnasResponse {
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

export async function resolveDownloadUrl(version: string): Promise<string> {
  const listRes = await fetch(LIST_API, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
  });
  if (!listRes.ok) throw new Error(`UGREEN LIST API HTTP ${listRes.status}`);

  const listData = (await listRes.json()) as UgnasListResponse;
  const item = listData.data?.appSoftVers?.find(
    (candidate) => candidate.appNo === "com.ugreenNasPro.mac" && Number(candidate.clientBit) === 3,
  );
  if (!item) throw new Error("UGREEN LIST API: no Apple Silicon macOS build found");

  const itemVersion = item.verName?.replace(/^v/, "");
  if (itemVersion !== version) {
    throw new Error(`UGREEN LIST API: requested version ${version} does not match current version ${itemVersion ?? "<missing>"}`);
  }

  const id = item.id;
  if (id == null) throw new Error("UGREEN LIST API: missing selected id");

  const res = await fetch(`${TEMP_LINK_API}?appType=client&id=${id}`, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
  });
  if (!res.ok) throw new Error(`UGREEN API HTTP ${res.status}`);

  const data = (await res.json()) as UgnasResponse;
  const tempUrl = data.data?.linkData?.tempUrl;
  if (!tempUrl) throw new Error(`UGREEN API: ${data.msg ?? "no tempUrl"}`);
  return tempUrl;
}

export const ugnas = new Hono();

ugnas.get("/dl", (c) => {
  const v = c.req.query("v");
  if (!v) {
    return c.text("Missing required query: v", 400);
  }
  return redirectProxy(c, {
    cacheKey: `ugnas/${v}`,
    resolve: () => resolveDownloadUrl(v),
    ttl: 300,
  });
});
