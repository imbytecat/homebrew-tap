import { afterEach, describe, expect, it, vi } from "vitest";
import { resolveDownloadUrl, ugnas } from "./ugnas";

afterEach(() => {
  vi.restoreAllMocks();
});

function mockFetchOnce(body: unknown, init: ResponseInit = {}) {
  return vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValueOnce(new Response(JSON.stringify(body), init));
}

describe("resolveDownloadUrl", () => {
  it("returns tempUrl on success", async () => {
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
    await expect(resolveDownloadUrl("1.16.0.77937")).resolves.toBe(
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
    await expect(resolveDownloadUrl("1.16.0.77937")).rejects.toThrow(/LIST API HTTP 503/);
  });

  it("throws when selected record is missing", async () => {
    mockFetchOnce({ data: { appSoftVers: [{ appNo: "com.other.app", clientBit: 3, id: 1, verName: "v1.16.0.77937" }] } });
    await expect(resolveDownloadUrl("1.16.0.77937")).rejects.toThrow(/no Apple Silicon macOS build found/);
  });

  it("throws when version does not match", async () => {
    mockFetchOnce({
      data: { appSoftVers: [{ appNo: "com.ugreenNasPro.mac", clientBit: 3, id: 536, verName: "v1.16.0.77936" }] },
    });
    await expect(resolveDownloadUrl("1.16.0.77937")).rejects.toThrow(/does not match current version 1.16.0.77936/);
  });

  it("throws on non-2xx temp-link HTTP", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { appSoftVers: [{ appNo: "com.ugreenNasPro.mac", clientBit: 3, id: 536, verName: "v1.16.0.77937" }] } })),
      )
      .mockResolvedValueOnce(new Response("", { status: 502 }));
    await expect(resolveDownloadUrl("1.16.0.77937")).rejects.toThrow(/HTTP 502/);
  });

  it("throws when tempUrl is missing", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { appSoftVers: [{ appNo: "com.ugreenNasPro.mac", clientBit: 3, id: 536, verName: "v1.16.0.77937" }] } })),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify({ msg: "captcha required", data: {} })));
    await expect(resolveDownloadUrl("1.16.0.77937")).rejects.toThrow(/captcha required/);
  });
});

describe("ugnas Hono app", () => {
  it("rejects missing v with 400", async () => {
    const res = await ugnas.request("/dl");
    expect(res.status).toBe(400);
  });
});
