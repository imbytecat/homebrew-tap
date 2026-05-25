import { Hono } from "hono";
import { ugnas } from "./vendors/ugnas";

const app = new Hono();

app.get("/", (c) => c.text("homebrew-proxy: https://github.com/imbytecat/homebrew-tap\n"));

app.route("/ugnas", ugnas);

export default app;
