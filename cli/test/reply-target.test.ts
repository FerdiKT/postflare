import { describe, expect, it } from "vitest";
import { replyTargetId } from "../src/commands/posts";

describe("posts comment --reply-to", () => {
  it("takes ids as they are and the reply id out of links", () => {
    expect(replyTargetId("UgxTOP.9REPLY")).toBe("UgxTOP.9REPLY");
    expect(replyTargetId("https://www.youtube.com/watch?v=VID123&lc=UgxTOP")).toBe("UgxTOP");
    expect(replyTargetId("https://youtube.com/shorts/VID123?lc=UgyABC.1")).toBe("UgyABC.1");
    expect(replyTargetId("https://x.com/someone/status/123")).toBe("123");
    expect(replyTargetId("https://bsky.app/profile/a.bsky.social/post/3abc")).toBe("3abc");
  });
});
