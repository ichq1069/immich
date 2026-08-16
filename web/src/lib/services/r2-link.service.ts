import { getBaseUrl } from '@immich/sdk';
import { authManager } from '$lib/managers/auth-manager.svelte';

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

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const baseUrl = getBaseUrl();
  const apiKey = authManager.params.key || '';

  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      ...options.headers,
    },
  });

  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }

  return response.json();
}

export async function createR2Links(dto: CreateR2LinksDto): Promise<R2LinkResponse[]> {
  return request<R2LinkResponse[]>('/r2-links', {
    method: 'POST',
    body: JSON.stringify(dto),
  });
}

export async function getR2Links(): Promise<R2LinkResponse[]> {
  return request<R2LinkResponse[]>('/r2-links');
}

export async function revokeR2Link(id: string): Promise<void> {
  await request(`/r2-links/${id}`, { method: 'DELETE' });
}

export async function revokeR2Links(ids: string[]): Promise<void> {
  await request('/r2-links', {
    method: 'DELETE',
    body: JSON.stringify({ ids }),
  });
}