import { Injectable, Logger } from '@nestjs/common';
import { R2LinkRepository } from 'src/repositories/r2-link.repository';
import { AssetRepository } from 'src/repositories/asset.repository';
import { AccessRepository } from 'src/repositories/access.repository';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { requireAccess } from 'src/utils/access';
import { AuthDto } from 'src/dtos/auth.dto';
import { Permission } from 'src/enum';
import { ConfigRepository } from 'src/repositories/config.repository';

export type R2ExpiresIn = '1h' | '24h' | '7d' | 'permanent';

@Injectable()
export class R2LinkService {
  private logger = new Logger(R2LinkService.name);

  constructor(
    private r2LinkRepository: R2LinkRepository,
    private assetRepository: AssetRepository,
    private accessRepository: AccessRepository,
    private configRepository: ConfigRepository,
  ) {}

  async createLinks(auth: AuthDto, assetIds: string[], expiresIn: R2ExpiresIn) {
    const assetIdsList = [...new Set(assetIds)];

    await requireAccess(this.accessRepository, {
      auth,
      permission: Permission.AssetDownload,
      ids: assetIdsList,
    });

    const s3Client = this.createS3Client();

    const results = [];
    for (const assetId of assetIdsList) {
      const asset = await this.assetRepository.getById(assetId);
      if (!asset) {
        throw new Error(`Asset not found: ${assetId}`);
      }

      const r2Key = this.getR2Key(asset.originalPath);
      const expiresAt = this.getExpiresAt(expiresIn);

      const url = await this.generatePresignedUrl(s3Client, r2Key, expiresAt);
      const link = await this.r2LinkRepository.create({
        assetId,
        userId: auth.user.id,
        url,
        expiresAt,
      });

      results.push(link);
    }

    return results;
  }

  async getLinks(auth: AuthDto) {
    return this.r2LinkRepository.getByUserId(auth.user.id);
  }

  async revokeLink(auth: AuthDto, id: string) {
    return this.r2LinkRepository.revoke(id, auth.user.id);
  }

  async revokeLinks(auth: AuthDto, ids: string[]) {
    return this.r2LinkRepository.revokeAll(ids, auth.user.id);
  }

  private createS3Client(): S3Client {
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const endpoint = process.env.R2_ENDPOINT;

    if (!accessKeyId || !secretAccessKey || !endpoint) {
      throw new Error('R2 credentials not configured');
    }

    return new S3Client({
      region: 'auto',
      endpoint,
      credentials: { accessKeyId, secretAccessKey },
      forcePathStyle: true,
    });
  }

  private getR2Key(originalPath: string): string {
    const uploadLocation = process.env.UPLOAD_LOCATION || '/root/immich-tk/r2-immich-photo';
    const r2Key = originalPath.startsWith(uploadLocation)
      ? originalPath.slice(uploadLocation.length).replace(/^\/+/, '')
      : originalPath;
    return r2Key;
  }

  private getExpiresAt(expiresIn: R2ExpiresIn): Date | null {
    switch (expiresIn) {
      case '1h':
        return new Date(Date.now() + 3600 * 1000);
      case '24h':
        return new Date(Date.now() + 86400 * 1000);
      case '7d':
        return new Date(Date.now() + 604800 * 1000);
      case 'permanent':
        return null;
      default:
        return new Date(Date.now() + 3600 * 1000);
    }
  }

  private async generatePresignedUrl(client: S3Client, key: string, expiresAt: Date | null): Promise<string> {
    const bucket = process.env.R2_BUCKET_NAME || 'immich-photo';
    const customDomain = process.env.R2_CUSTOM_DOMAIN;

    // If custom domain is configured, use it for the URL
    if (customDomain) {
      const url = `https://${customDomain}/${key}`;
      if (expiresAt) {
        const expiresInSeconds = Math.max(1, Math.floor((expiresAt.getTime() - Date.now()) / 1000));
        const command = new GetObjectCommand({ Bucket: bucket, Key: key });
        const presignedUrl = await getSignedUrl(client, command, { expiresIn: expiresInSeconds });
        // Replace the S3 endpoint with custom domain
        return presignedUrl.replace(/https:\/\/[^/]+/, `https://${customDomain}`);
      }
      // For permanent links, generate a very long-lived presigned URL
      const command = new GetObjectCommand({ Bucket: bucket, Key: key });
      const presignedUrl = await getSignedUrl(client, command, { expiresIn: 86400 * 365 * 10 });
      return presignedUrl.replace(/https:\/\/[^/]+/, `https://${customDomain}`);
    }

    // Fallback to presigned URL with S3 endpoint
    if (expiresAt) {
      const expiresInSeconds = Math.max(1, Math.floor((expiresAt.getTime() - Date.now()) / 1000));
      const command = new GetObjectCommand({ Bucket: bucket, Key: key });
      return getSignedUrl(client, command, { expiresIn: expiresInSeconds });
    }

    const command = new GetObjectCommand({ Bucket: bucket, Key: key });
    return getSignedUrl(client, command, { expiresIn: 86400 * 365 * 10 });
  }
}
