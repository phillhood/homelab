import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { TotpService } from './totp.service';
import { TokenCleanupService } from './token-cleanup.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import {
  User,
  RefreshToken,
  TotpSecret,
  OauthAccount,
  InviteCode,
  PasswordReset,
} from './entities';
import { MailModule } from '../mail/mail.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      RefreshToken,
      TotpSecret,
      OauthAccount,
      InviteCode,
      PasswordReset,
    ]),
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('jwt.secret'),
        signOptions: {
          expiresIn: configService.get<string>('jwt.accessExpiresIn') as any,
        },
      }),
      inject: [ConfigService],
    }),
    MailModule,
  ],
  controllers: [AuthController],
  providers: [AuthService, TotpService, TokenCleanupService, JwtStrategy],
  exports: [AuthService, JwtStrategy, TypeOrmModule],
})
export class AuthModule {}
