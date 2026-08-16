import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`
    CREATE TABLE "r2_links" (
      "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
      "assetId" uuid NOT NULL,
      "userId" uuid NOT NULL,
      "url" text NOT NULL,
      "expiresAt" timestamptz,
      "createdAt" timestamptz NOT NULL DEFAULT now(),
      "revokedAt" timestamptz
    );
  `.execute(db);

  await sql`ALTER TABLE "r2_links" ADD CONSTRAINT "r2_links_pkey" PRIMARY KEY ("id");`.execute(db);
  await sql`ALTER TABLE "r2_links" ADD CONSTRAINT "r2_links_assetId_fkey"
    FOREIGN KEY ("assetId") REFERENCES "asset" ("id") ON UPDATE CASCADE ON DELETE CASCADE;`.execute(db);
  await sql`ALTER TABLE "r2_links" ADD CONSTRAINT "r2_links_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "user" ("id") ON UPDATE CASCADE ON DELETE CASCADE;`.execute(db);
  await sql`CREATE INDEX "r2_links_userId_idx" ON "r2_links" ("userId");`.execute(db);
  await sql`CREATE INDEX "r2_links_assetId_idx" ON "r2_links" ("assetId");`.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`DROP TABLE IF EXISTS "r2_links";`.execute(db);
}