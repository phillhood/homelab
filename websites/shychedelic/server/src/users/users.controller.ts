import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { IsString, IsOptional, IsInt, Min, Max } from 'class-validator';
import { v4 as uuidv4 } from 'uuid';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User, UserRole } from '../auth/entities/user.entity';
import { InviteCode } from '../auth/entities/invite-code.entity';

class CreateInviteDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  maxUses?: number;

  @IsOptional()
  @IsString()
  expiresIn?: string;
}

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(
    @InjectRepository(InviteCode)
    private inviteCodesRepository: Repository<InviteCode>,
  ) {}

  @Get('invites')
  @Roles(UserRole.ADMIN)
  async listInvites() {
    return this.inviteCodesRepository.find({
      order: { createdAt: 'DESC' },
      relations: ['creator'],
    });
  }

  @Post('invites')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  async createInvite(
    @CurrentUser() user: User,
    @Body() dto: CreateInviteDto,
  ) {
    let expiresAt: Date | undefined;
    if (dto.expiresIn) {
      const hours = parseInt(dto.expiresIn, 10);
      if (!isNaN(hours) && hours > 0) {
        expiresAt = new Date(Date.now() + hours * 60 * 60 * 1000);
      }
    }

    const invite = this.inviteCodesRepository.create({
      code: uuidv4().split('-')[0],
      createdBy: user.id,
      maxUses: dto.maxUses || 1,
      expiresAt: expiresAt ?? undefined,
    });

    return this.inviteCodesRepository.save(invite);
  }
}
