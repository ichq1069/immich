import { Column, CreateDateColumn, ForeignKeyColumn, Generated, PrimaryGeneratedColumn, Table, Timestamp } from '@immich/sql-tools';
import { UserTable } from 'src/schema/tables/user.table';
import { AssetTable } from 'src/schema/tables/asset.table';

@Table('r2_links')
export class R2LinkTable {
  @PrimaryGeneratedColumn()
  id!: Generated<string>;

  @ForeignKeyColumn(() => AssetTable, { onDelete: 'CASCADE', onUpdate: 'CASCADE', nullable: false })
  assetId!: string;

  @ForeignKeyColumn(() => UserTable, { onDelete: 'CASCADE', onUpdate: 'CASCADE', nullable: false })
  userId!: string;

  @Column({ type: 'text' })
  url!: string;

  @Column({ type: 'timestamptz', nullable: true })
  expiresAt!: Timestamp | null;

  @CreateDateColumn()
  createdAt!: Generated<Timestamp>;

  @Column({ type: 'timestamptz', nullable: true })
  revokedAt!: Timestamp | null;
}