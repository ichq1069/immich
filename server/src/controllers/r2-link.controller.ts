import { Controller, Delete, Get, Post, Body, Param, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, Authenticated } from 'src/decorators/auth-user.decorator';
import { AuthUserDto } from 'src/dto/auth-user.dto';
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
@Authenticated()
export class R2LinkController {
  constructor(private r2LinkService: R2LinkService) {}

  @Post()
  createLinks(@AuthUser() authUser: AuthUserDto, @Body() dto: CreateR2LinksDto) {
    return this.r2LinkService.createLinks(authUser, dto.assetIds, dto.expiresIn || '1h');
  }

  @Get()
  getLinks(@AuthUser() authUser: AuthUserDto) {
    return this.r2LinkService.getLinks(authUser);
  }

  @Delete(':id')
  revokeLink(@AuthUser() authUser: AuthUserDto, @Param('id') id: string) {
    return this.r2LinkService.revokeLink(authUser, id);
  }

  @Delete()
  revokeLinks(@AuthUser() authUser: AuthUserDto, @Body() dto: RevokeR2LinksDto) {
    return this.r2LinkService.revokeLinks(authUser, dto.ids);
  }
}