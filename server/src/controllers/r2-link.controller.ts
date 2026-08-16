import { Controller, Delete, Get, Post, Body, Param } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Auth, Authenticated } from 'src/middleware/auth.guard';
import { Endpoint } from 'src/decorators';
import { AuthDto } from 'src/dtos/auth.dto';
import { Permission } from 'src/enum';
import { R2LinkService, R2ExpiresIn } from 'src/services/r2-link.service';

class CreateR2LinksDto {
  assetIds!: string[];
  expiresIn!: R2ExpiresIn;
}

class RevokeR2LinksDto {
  ids!: string[];
}

@ApiTags('R2 Links')
@Controller('r2-links')
export class R2LinkController {
  constructor(private r2LinkService: R2LinkService) {}

  @Post()
  @Authenticated({ permission: Permission.AssetDownload })
  @Endpoint({ summary: 'Create R2 direct links for assets' })
  createLinks(@Auth() auth: AuthDto, @Body() dto: CreateR2LinksDto) {
    return this.r2LinkService.createLinks(auth, dto.assetIds, dto.expiresIn || '1h');
  }

  @Get()
  @Authenticated({ permission: Permission.AssetDownload })
  @Endpoint({ summary: 'Get all R2 direct links' })
  getLinks(@Auth() auth: AuthDto) {
    return this.r2LinkService.getLinks(auth);
  }

  @Delete(':id')
  @Authenticated({ permission: Permission.AssetDownload })
  @Endpoint({ summary: 'Revoke an R2 direct link' })
  revokeLink(@Auth() auth: AuthDto, @Param('id') id: string) {
    return this.r2LinkService.revokeLink(auth, id);
  }

  @Delete()
  @Authenticated({ permission: Permission.AssetDownload })
  @Endpoint({ summary: 'Revoke multiple R2 direct links' })
  revokeLinks(@Auth() auth: AuthDto, @Body() dto: RevokeR2LinksDto) {
    return this.r2LinkService.revokeLinks(auth, dto.ids);
  }
}
