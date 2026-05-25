import { Hono } from "hono";
import { ugnas } from "./vendors/ugnas";

const app = new Hono();

app.get("/", (c) =>
  c.text(
    "homebrew-proxy: signed-URL resolver for Homebrew taps.\n" +
      "Routes:\n" +
      "  GET /ugnas/dl?id=<appId>  -> 302 to UGREEN signed DMG URL\n",
  ),
);

app.route("/ugnas", ugnas);

export default app;
