ALTER TABLE "Character"
  ADD COLUMN "gold"      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "equipment" JSONB   NOT NULL DEFAULT '{}'::jsonb;
