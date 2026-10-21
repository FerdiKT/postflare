import { env } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { makeCall } from "./app-helpers";

// Connecting accounts: the OAuth connect URL. Own D1 instance (ACCOUNTS_DB); R2 is the shared test bucket.

const E = { ...env, DB: env.ACCOUNTS_DB, DEMO_MODE: "false", PUBLIC_URL: "https://pf.test", MEDIA_PUBLIC_URL: undefined } as unknown as Env;
const call = makeCall(E);
let owner: { cookie: string };

beforeAll(async () => {
  const setup = await call(null, "/api/auth/setup", { body: { name: "Ann", email: "ann@example.com", password: "password123", workspaceName: "Ann" } });
  expect(setup.status, setup.text).toBe(200);
  owner = { cookie: setup.cookie! };
  const app = await call(owner, "/api/platforms/instagram_standalone", { method: "PUT", body: { values: { clientId: "IGAPP", clientSecret: "IGSECRET" } } });
  expect(app.status, app.text).toBe(200);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("GET /api/connect/:provider/url", () => {
  it("never forces the Instagram login by default; switchAccount=1 opts in", async () => {
    const plain = await call(owner, "/api/connect/instagram_standalone/url");
    expect(plain.status, plain.text).toBe(200);
    expect(new URL(plain.json.url).searchParams.has("force_reauth")).toBe(false);
    const other = await call(owner, "/api/connect/instagram_standalone/url?switchAccount=1");
    expect(new URL(other.json.url).searchParams.get("force_reauth")).toBe("true");
    const platforms = await call(owner, "/api/providers");
    const ig = platforms.json.find((p: any) => p.id === "instagram_standalone");
    expect(ig.switchAccount).toMatchObject({ label: "Use a different Instagram account" });
  });
});
