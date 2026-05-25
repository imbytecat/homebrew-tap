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
    const fetchSpy = mockFetchOnce({
      data: { linkData: { tempUrl: "https://cdn.example.com/file.dmg?sig=abc" } },
    });
    await expect(resolveDownloadUrl("515")).resolves.toBe(
      "https://cdn.example.com/file.dmg?sig=abc",
    );
    expect(fetchSpy).toHaveBeenCalledWith(
      expect.stringContaining("id=515"),
      expect.objectContaining({ headers: expect.any(Object) }),
    );
  });

  it("throws on non-2xx HTTP", async () => {
    mockFetchOnce({}, { status: 503 });
    await expect(resolveDownloadUrl("515")).rejects.toThrow(/HTTP 503/);
  });

  it("throws when tempUrl is missing", async () => {
    mockFetchOnce({ msg: "captcha required", data: {} });
    await expect(resolveDownloadUrl("515")).rejects.toThrow(/captcha required/);
  });
});

describe("ugnas Hono app", () => {
  it("rejects unknown id with 400", async () => {
    const res = await ugnas.request("/dl?id=516&v=1.0.0");
    expect(res.status).toBe(400);
  });

  it("rejects missing id with 400", async () => {
    const res = await ugnas.request("/dl");
    expect(res.status).toBe(400);
  });

  it("rejects missing v with 400", async () => {
    const res = await ugnas.request("/dl?id=515");
    expect(res.status).toBe(400);
  });
});
