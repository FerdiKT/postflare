import { env } from "cloudflare:test";
import { beforeAll, describe, expect, it } from "vitest";
import { sweepMedia } from "../../worker/lib/media-lifecycle";
import { makeCall } from "./app-helpers";

// "Delete after publishing" (worker/lib/media-lifecycle.ts rule d): files whose posts are all published are removed N
// days after the last publish; files of posts still in progress are kept; media status answers after removal too.
// Own D1 (MEDIA_GC_DB); R2 is the shared test bucket (keys hold unique ids).

const DB = env.MEDIA_GC_DB;
const E = { ...env, DB, DEMO_MODE: "false", PUBLIC_URL: "https://pf.test" } as unknown as Env;
const call = makeCall(E);
const DAY = 86_400_000;
let owner: { cookie: string; ws: string };

async function media(id: string, filename: string, size = 1000) {
  await DB.prepare("INSERT INTO media (id, r2_key, filename, mime, size, kind, status, created_at, workspace_id) VALUES (?, ?, ?, 'video/mp4', ?, 'video', 'ready', ?, ?)")
    .bind(id, `${id}/${filename}`, filename, size, Date.now() - 10 * DAY, owner.ws)
    .run();
  await env.MEDIA.put(`${id}/${filename}`, "x");
}
async function post(id: string, status: string, mediaId: string, publishedAgo: number | null, account = "acc_gc_yt") {
  const t = Date.now();
  await DB.prepare(
    `INSERT INTO posts (id, group_id, account_id, status, scheduled_at, content, media, created_at, updated_at, published_at, workspace_id, external_url)
     VALUES (?, ?, ?, ?, ?, '', ?, ?, ?, ?, ?, ?)`,
  )
    .bind(id, `grp_${id}`, account, status, t, JSON.stringify([mediaId]), t - 10 * DAY, t, publishedAgo === null ? null : t - publishedAgo, owner.ws, status === "published" ? `https://youtu.be/${id}` : null)
    .run();
}

beforeAll(async () => {
  const setup = await call(null, "/api/auth/setup", { body: { name: "Gc", email: "gc@example.com", password: "password123", workspaceName: "Gc" } });
  expect(setup.status, setup.text).toBe(200);
  const ws = (await call({ cookie: setup.cookie! }, "/api/workspaces")).json[0].id;
  owner = { cookie: setup.cookie!, ws };
  const t = Date.now();
  for (const [id, provider] of [["acc_gc_yt", "youtube"], ["acc_gc_tt", "tiktok"], ["acc_gc_dev", "devto"]]) {
    await DB.prepare("INSERT INTO accounts (id, provider, external_id, name, credentials_enc, created_at, updated_at, workspace_id) VALUES (?, ?, ?, ?, 'x', ?, ?, ?)")
      .bind(id, provider, id, id, t, t, ws)
      .run();
  }
  // Published on YouTube and TikTok 5 days ago: goes.
  await media("med_gc_old", "old.mp4", 5000);
  await post("pst_gc_a", "published", "med_gc_old", 5 * DAY);
  await post("pst_gc_b", "published", "med_gc_old", 4 * DAY, "acc_gc_tt");
  // One platform published, the other still scheduled: stays.
  await media("med_gc_half", "half.mp4");
  await post("pst_gc_c", "published", "med_gc_half", 5 * DAY);
  await post("pst_gc_d", "scheduled", "med_gc_half", null, "acc_gc_tt");
  // Failed on one platform: stays.
  await media("med_gc_failed", "failed.mp4");
  await post("pst_gc_e", "published", "med_gc_failed", 5 * DAY);
  await post("pst_gc_f", "failed", "med_gc_failed", null, "acc_gc_tt");
  // Published yesterday: stays until day 3.
  await media("med_gc_new", "new.mp4");
  await post("pst_gc_g", "published", "med_gc_new", 1 * DAY);
  // A platform that links to our copy (DEV): stays.
  await media("med_gc_hot", "hot.png");
  await post("pst_gc_h", "published", "med_gc_hot", 9 * DAY, "acc_gc_dev");
});

describe("delete after publishing", () => {
  it("dry run lists only files published everywhere more than 3 days ago", async () => {
    const r = await call(owner, "/api/media/gc", { body: { dryRun: true } });
    expect(r.status, r.text).toBe(200);
    expect(r.json).toMatchObject({ dryRun: true, days: 3, count: 1, bytes: 5000, items: [{ id: "med_gc_old", filename: "old.mp4" }] });
    expect(await DB.prepare("SELECT COUNT(*) AS n FROM media WHERE id = 'med_gc_old'").first("n")).toBe(1);
  });

  it("status says not published yet while a post is pending", async () => {
    const r = await call(owner, "/api/media/status?filename=half.mp4");
    expect(r.json).toMatchObject({ published: false, matches: [{ id: "med_gc_half", inStorage: true, published: false, pending: 1 }] });
    expect((await call(owner, "/api/media/status?filename=nope.mp4")).json).toEqual({ published: false, matches: [] });
    expect((await call(owner, "/api/media/status")).status).toBe(400);
  });

  it("gc deletes the file and its R2 object; status still answers from the tombstone", async () => {
    const r = await call(owner, "/api/media/gc", { body: {} });
    expect(r.json).toMatchObject({ dryRun: false, count: 1 });
    expect(await DB.prepare("SELECT COUNT(*) AS n FROM media WHERE id = 'med_gc_old'").first("n")).toBe(0);
    expect(await env.MEDIA.head("med_gc_old/old.mp4")).toBeNull();
    const s = await call(owner, "/api/media/status?filename=old.mp4&size=5000");
    expect(s.json).toMatchObject({ published: true, matches: [{ id: "med_gc_old", inStorage: false, deletedReason: "published", published: true, pending: 0 }] });
    expect(s.json.matches[0].posts.map((p: any) => p.url)).toEqual(["https://youtu.be/pst_gc_a", "https://youtu.be/pst_gc_b"]);
    // The others are untouched.
    const left = (await DB.prepare("SELECT id FROM media ORDER BY id").all<{ id: string }>()).results.map((x) => x.id);
    expect(left).toEqual(["med_gc_failed", "med_gc_half", "med_gc_hot", "med_gc_new"]);
  });

  it("days can be overridden; the daily sweep applies the instance setting", async () => {
    expect((await call(owner, "/api/media/gc", { body: { days: -1 } })).status).toBe(400);
    expect((await call(owner, "/api/media/gc", { body: { days: 0, dryRun: true } })).json.items.map((i: any) => i.id)).toEqual(["med_gc_new"]);
    expect((await call(owner, "/api/settings", { method: "PUT", body: { mediaPublishedRetentionDays: 0 } })).status).toBe(200);
    expect((await sweepMedia(E)).published).toBe(0);
    await call(owner, "/api/settings", { method: "PUT", body: { mediaPublishedRetentionDays: 1 } });
    expect((await call(owner, "/api/settings")).json.mediaPublishedRetentionDays).toBe(1);
    await DB.prepare("UPDATE posts SET published_at = ? WHERE id = 'pst_gc_g'").bind(Date.now() - 2 * DAY).run();
    expect((await sweepMedia(E)).published).toBe(1);
    expect((await call(owner, "/api/media/status?id=med_gc_new")).json).toMatchObject({ published: true, matches: [{ inStorage: false }] });
  });

  it("a file deleted by hand leaves a tombstone too", async () => {
    expect((await call(owner, "/api/media/med_gc_hot", { method: "DELETE" })).status).toBe(200);
    expect((await call(owner, "/api/media/status?id=med_gc_hot")).json.matches[0]).toMatchObject({ inStorage: false, deletedReason: "manual" });
  });
});
