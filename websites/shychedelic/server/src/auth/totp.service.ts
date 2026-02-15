import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { authenticator } from 'otplib';
import * as QRCode from 'qrcode';
import { User } from './entities/user.entity';
import { TotpSecret } from './entities/totp-secret.entity';
import { AuthService } from './auth.service';

const BCRYPT_ROUNDS = 12;
const ALGORITHM = 'aes-256-gcm';

@Injectable()
export class TotpService {
  private encryptionKey: Buffer;

  constructor(
    @InjectRepository(TotpSecret) private totpRepository: Repository<TotpSecret>,
    @InjectRepository(User) private usersRepository: Repository<User>,
    private jwtService: JwtService,
    private configService: ConfigService,
    private authService: AuthService,
  ) {
    const key = this.configService.get<string>('TOTP_ENCRYPTION_KEY') || '';
    this.encryptionKey = crypto
      .createHash('sha256')
      .update(key)
      .digest();
  }

  private encrypt(text: string): string {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(ALGORITHM, this.encryptionKey, iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag();
    return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
  }

  private decrypt(encryptedText: string): string {
    const [ivHex, authTagHex, encrypted] = encryptedText.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const decipher = crypto.createDecipheriv(ALGORITHM, this.encryptionKey, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  private generateBackupCodes(): string[] {
    return Array.from({ length: 8 }, () =>
      crypto.randomBytes(4).toString('hex'),
    );
  }

  async setup(user: User): Promise<{ secret: string; qrUrl: string }> {
    const existing = await this.totpRepository.findOne({
      where: { userId: user.id, isEnabled: true },
    });

    if (existing) {
      throw new BadRequestException('TOTP is already enabled');
    }

    const secret = authenticator.generateSecret();
    const otpauthUrl = authenticator.keyuri(
      user.email,
      'shychedelic',
      secret,
    );
    const qrUrl = await QRCode.toDataURL(otpauthUrl);

    const encrypted = this.encrypt(secret);

    const totpRecord = await this.totpRepository.findOne({
      where: { userId: user.id },
    });

    if (totpRecord) {
      totpRecord.secret = encrypted;
      totpRecord.isEnabled = false;
      await this.totpRepository.save(totpRecord);
    } else {
      await this.totpRepository.save(
        this.totpRepository.create({
          userId: user.id,
          secret: encrypted,
          isEnabled: false,
        }),
      );
    }

    return { secret, qrUrl };
  }

  async enable(
    user: User,
    code: string,
  ): Promise<{ backupCodes: string[] }> {
    const totpRecord = await this.totpRepository.findOne({
      where: { userId: user.id },
    });

    if (!totpRecord) {
      throw new BadRequestException('TOTP not set up. Call /auth/totp/setup first');
    }

    if (totpRecord.isEnabled) {
      throw new BadRequestException('TOTP is already enabled');
    }

    const secret = this.decrypt(totpRecord.secret);
    const isValid = authenticator.verify({ token: code, secret });

    if (!isValid) {
      throw new BadRequestException('Invalid TOTP code');
    }

    const backupCodes = this.generateBackupCodes();
    const hashedCodes = await Promise.all(
      backupCodes.map((c) => bcrypt.hash(c, BCRYPT_ROUNDS)),
    );

    totpRecord.isEnabled = true;
    totpRecord.backupCodes = hashedCodes;
    await this.totpRepository.save(totpRecord);

    return { backupCodes };
  }

  async disable(user: User, password: string): Promise<void> {
    const passwordValid = await bcrypt.compare(password, user.passwordHash);
    if (!passwordValid) {
      throw new UnauthorizedException('Invalid password');
    }

    const totpRecord = await this.totpRepository.findOne({
      where: { userId: user.id },
    });

    if (!totpRecord || !totpRecord.isEnabled) {
      throw new BadRequestException('TOTP is not enabled');
    }

    await this.totpRepository.remove(totpRecord);
  }

  async verifyLogin(
    totpChallenge: string,
    code: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: Partial<User> }> {
    let payload: { sub: string; type: string };
    try {
      payload = this.jwtService.verify(totpChallenge);
    } catch {
      throw new UnauthorizedException('Invalid or expired TOTP challenge');
    }

    if (payload.type !== 'totp-challenge') {
      throw new UnauthorizedException('Invalid token type');
    }

    const user = await this.usersRepository.findOne({
      where: { id: payload.sub },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const totpRecord = await this.totpRepository.findOne({
      where: { userId: user.id, isEnabled: true },
    });

    if (!totpRecord) {
      throw new UnauthorizedException('TOTP not enabled');
    }

    const secret = this.decrypt(totpRecord.secret);
    const isValid = authenticator.verify({ token: code, secret });

    if (!isValid) {
      let backupUsed = false;
      for (let i = 0; i < totpRecord.backupCodes.length; i++) {
        const match = await bcrypt.compare(code, totpRecord.backupCodes[i]);
        if (match) {
          totpRecord.backupCodes.splice(i, 1);
          await this.totpRepository.save(totpRecord);
          backupUsed = true;
          break;
        }
      }

      if (!backupUsed) {
        throw new UnauthorizedException('Invalid TOTP code');
      }
    }

    const tokens = await this.authService.generateTokens(user);

    return {
      ...tokens,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        emailVerified: user.emailVerified,
      },
    };
  }
}
