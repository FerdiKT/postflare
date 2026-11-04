-- Media removed from storage (daily sweep, `media gc`, or deleted by hand): `GET /api/media/status` still answers
-- whether a file was published after it is gone. Kept 180 days (daily cleanup).
CREATE TABLE media_tombstones (
  id TEXT PRIMARY KEY, -- the media id
  workspace_id TEXT,
  filename TEXT NOT NULL,
  size INTEGER NOT NULL,
  created_at INTEGER NOT NULL, -- upload time
  deleted_at INTEGER NOT NULL,
  reason TEXT NOT NULL -- published | retention | unused_link | manual
);
CREATE INDEX media_tombstones_name ON media_tombstones (workspace_id, filename);
CREATE INDEX media_tombstones_deleted ON media_tombstones (deleted_at);
CREATE INDEX media_name ON media (workspace_id, filename);
