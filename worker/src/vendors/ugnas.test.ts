import { afterEach, describe, expect, it, vi } from "vitest";
import { resolveById, resolveByVersion, ugnas } from "./ugnas";

afterEach(() => {
  vi.restoreAllMocks();
});

function mockFetchOnce(body: unknown, init: ResponseInit = {}) {
  return vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValueOnce(new Response(JSON.stringify(body), init));
}

describe("resolveById", () => {
  it("returns tempUrl on success", async () => {
    const fetchSpy = mockFetchOnce({
      data: { linkData: { tempUrl: "https://cdn.example.com/file.dmg?sig=abc" } },
    });
    await expect(resolveById("536")).resolves.toBe("https://cdn.example.com/file.dmg?sig=abc");
    expect(fetchSpy).toHaveBeenCalledWith(
      expect.stringContaining("id=536"),
      expect.objectContaining({ headers: expect.any(Object) }),
    );
  });

  it("throws on non-2xx HTTP", async () => {
    mockFetchOnce({}, { status: 502 });
    await expect(resolveById("536")).rejects.toThrow(/TEMP_LINK HTTP 502/);
  });

  it("throws when tempUrl is missing", async () => {
    mockFetchOnce({ msg: "captcha required", data: {} });
    await expect(resolveById("536")).rejects.toThrow(/captcha required/);
  });

  it("url-encodes the id query", async () => {
    const fetchSpy = mockFetchOnce({
      data: { linkData: { tempUrl: "https://cdn.example.com/x" } },
    });
    await resolveById("5 36");
    expect(fetchSpy).toHaveBeenCalledWith(
      expect.stringContaining("id=5%2036"),
      expect.any(Object),
    );
  });
});

describe("resolveByVersion (fallback)", () => {
  it("returns tempUrl when LIST + TEMP_LINK both succeed", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: {
              appSoftVers: [
                { appNo: "com.ugreenNasPro.mac", clientBit: 3, id: 536, verName: "v1.16.0.77937" },
              ],
            },
          }),
        ),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { linkData: { tempUrl: "https://cdn.example.com/file.dmg?sig=abc" } } })),
      );
    await expect(resolveByVersion("1.16.0.77937")).resolves.toBe(
      "https://cdn.example.com/file.dmg?sig=abc",
    );
    expect(fetchSpy).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining("id=536"),
      expect.objectContaining({ headers: expect.any(Object) }),
    );
  });

  it("throws on non-2xx LIST HTTP", async () => {
    mockFetchOnce({}, { status: 503 });
    await expect(resolveByVersion("1.16.0.77937")).rejects.toThrow(/LIST API HTTP 503/);
  });

  it("throws when selected record is missing", async () => {
    mockFetchOnce({ data: { appSoftVers: [{ appNo: "com.other.app", clientBit: 3, id: 1, verName: "v1.16.0.77937" }] } });
    await expect(resolveByVersion("1.16.0.77937")).rejects.toThrow(/no Apple Silicon macOS build found/);
  });

  it("throws when version does not match, including brew-update hint", async () => {
    mockFetchOnce({
      data: { appSoftVers: [{ appNo: "com.ugreenNasPro.mac", clientBit: 3, id: 537, verName: "v1.17.0.99999" }] },
    });
    const err = await resolveByVersion("1.16.0.77937").catch((e) => e);
    expect(err.message).toMatch(/1.16.0.77937/);
    expect(err.message).toMatch(/upstream now 1.17.0.99999/);
    expect(err.message).toMatch(/brew update/);
  });

  it("throws on non-2xx TEMP_LINK HTTP", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { appSoftVers: [{ appNo: "com.ugreenNasPro.mac", clientBit: 3, id: 536, verName: "v1.16.0.77937" }] } })),
      )
      .mockResolvedValueOnce(new Response("", { status: 502 }));
    await expect(resolveByVersion("1.16.0.77937")).rejects.toThrow(/TEMP_LINK HTTP 502/);
  });
});

describe("ugnas Hono app", () => {
  it("rejects missing v with 400", async () => {
    const res = await ugnas.request("/dl");
    expect(res.status).toBe(400);
    expect(await res.text()).toMatch(/Missing required query: v/);
  });

  it("rejects non-numeric id with 400", async () => {
    const res = await ugnas.request("/dl?v=1.0.0&id=abc");
    expect(res.status).toBe(400);
    expect(await res.text()).toMatch(/Invalid id/);
  });
});
