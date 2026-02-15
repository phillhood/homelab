import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { RefreshToken } from './entities/refresh-token.entity';
import { PasswordReset } from './entities/password-reset.entity';

@Injectable()
export class TokenCleanupService {
  private readonly logger = new Logger(TokenCleanupService.name);

  constructor(
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepo: Repository<RefreshToken>,
    @InjectRepository(PasswordReset)
    private readonly passwordResetRepo: Repository<PasswordReset>,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async cleanup() {
    const now = new Date();

    const expiredTokens = await this.refreshTokenRepo.delete({
      expiresAt: LessThan(now),
    });

    const revokedTokens = await this.refreshTokenRepo.delete({
      revoked: true,
    });

    const expiredResets = await this.passwordResetRepo.delete({
      expiresAt: LessThan(now),
    });

    const usedResets = await this.passwordResetRepo.delete({
      used: true,
    });

    const total =
      (expiredTokens.affected ?? 0) +
      (revokedTokens.affected ?? 0) +
      (expiredResets.affected ?? 0) +
      (usedResets.affected ?? 0);

    if (total > 0) {
      this.logger.log(
        `Cleaned up ${expiredTokens.affected} expired tokens, ${revokedTokens.affected} revoked tokens, ${expiredResets.affected} expired resets, ${usedResets.affected} used resets`,
      );
    }
  }
}
