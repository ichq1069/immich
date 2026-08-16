import { Injectable } from '@nestjs/common';
import { Kysely } from 'kysely';
import { InjectKysely } from 'nestjs-kysely';
import { DB } from 'src/schema';
import { R2LinkTable } from 'src/schema/tables/r2-link.table';

@Injectable()
export class R2LinkRepository {
  constructor(@InjectKysely() private db: Kysely<DB>) {}

  create(dto: { assetId: string; userId: string; url: string; expiresAt: Date | null }) {
    return this.db
      .insertInto('r2_links')
      .values({
        assetId: dto.assetId,
        userId: dto.userId,
        url: dto.url,
        expiresAt: dto.expiresAt,
      })
      .returningAll()
      .executeTakeFirstOrThrow();
  }

  getByUserId(userId: string) {
    return this.db
      .selectFrom('r2_links')
      .selectAll()
      .where('r2_links.userId', '=', userId)
      .where('r2_links.revokedAt', 'is', null)
      .orderBy('r2_links.createdAt', 'desc')
      .execute();
  }

  getById(id: string) {
    return this.db
      .selectFrom('r2_links')
      .selectAll()
      .where('r2_links.id', '=', id)
      .executeTakeFirst();
  }

  revoke(id: string, userId: string) {
    return this.db
      .updateTable('r2_links')
      .set({ revokedAt: new Date() })
      .where('r2_links.id', '=', id)
      .where('r2_links.userId', '=', userId)
      .where('r2_links.revokedAt', 'is', null)
      .executeTakeFirst();
  }

  revokeAll(ids: string[], userId: string) {
    return this.db
      .updateTable('r2_links')
      .set({ revokedAt: new Date() })
      .where('r2_links.id', 'in', ids)
      .where('r2_links.userId', '=', userId)
      .where('r2_links.revokedAt', 'is', null)
      .execute();
  }
}