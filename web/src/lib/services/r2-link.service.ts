import { get, post, del } from '@immich/sdk';
import type { AuthManager } from '$lib/managers/auth-manager.svelte';

export interface R2LinkResponse {
  id: string;
  assetId: string;
  userId: string;
  url: string;
  expiresAt: string | null;
  createdAt: string;
  revokedAt: string | null;
}

export interface CreateR2LinksDto {
  assetIds: string[];
  expiresIn: '1h' | '24h' | '7d' | 'permanent';
}

export async function createR2Links(auth: AuthManager, dto: CreateR2LinksDto): Promise<R2LinkResponse[]> {
  const { key } = auth.params;
  const response = await post('/r2-links', { ...dto }, { key });
  return response as unknown as R2LinkResponse[];
}

export async function getR2Links(auth: AuthManager): Promise<R2LinkResponse[]> {
  const { key } = auth.params;
  const response = await get('/r2-links', { key });
  return response as unknown as R2LinkResponse[];
}

export async function revokeR2Link(auth: AuthManager, id: string): Promise<void> {
  const { key } = auth.params;
  await del(`/r2-links/${id}`, { key });
}

export async function revokeR2Links(auth: AuthManager, ids: string[]): Promise<void> {
  const { key } = auth.params;
  await del('/r2-links', { ids }, { key });
}