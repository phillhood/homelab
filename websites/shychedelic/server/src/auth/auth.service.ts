import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { User } from './entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { InviteCode } from './entities/invite-code.entity';
import { PasswordReset } from './entities/password-reset.entity';
import { TotpSecret } from './entities/totp-secret.entity';
import { RegisterDto, LoginDto } from './dto';
import { MailService } from '../mail/mail.service';

const BCRYPT_ROUNDS = 12;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface LoginResponse {
  requiresTotp: boolean;
  totpChallenge?: string;
  accessToken?: string;
  refreshToken?: string;
  user?: Partial<User>;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private usersRepository: Repository<User>,
    @InjectRepository(RefreshToken) private refreshTokensRepository: Repository<RefreshToken>,
    @InjectRepository(InviteCode) private inviteCodesRepository: Repository<InviteCode>,
    @InjectRepository(PasswordReset) private passwordResetsRepository: Repository<PasswordReset>,
    @InjectRepository(TotpSecret) private totpSecretsRepository: Repository<TotpSecret>,
    private jwtService: JwtService,
    private configService: ConfigService,
    private mailService: MailService,
  ) {}

  async register(dto: RegisterDto): Promise<{ user: Partial<User> }> {
    const existingUser = await this.usersRepository.findOne({
      where: [{ email: dto.email }, { username: dto.username }],
    });

    if (existingUser) {
      if (existingUser.email === dto.email) {
        throw new ConflictException('Email already registered');
      }
      throw new ConflictException('Username already taken');
    }

    if (dto.inviteCode) {
      const invite = await this.inviteCodesRepository.findOne({
        where: { code: dto.inviteCode },
      });

      if (!invite) {
        throw new BadRequestException('Invalid invite code');
      }

      if (invite.expiresAt && invite.expiresAt < new Date()) {
        throw new BadRequestException('Invite code has expired');
      }

      if (invite.useCount >= invite.maxUses) {
        throw new BadRequestException('Invite code has been fully used');
      }

      invite.useCount += 1;
      await this.inviteCodesRepository.save(invite);
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);

    const user = this.usersRepository.create({
      email: dto.email,
      username: dto.username,
      passwordHash,
      displayName: dto.displayName || dto.username,
    });

    await this.usersRepository.save(user);

    const verifyToken = this.jwtService.sign(
      { sub: user.id, type: 'email-verify' },
      { expiresIn: '24h' },
    );
    await this.mailService.sendVerificationEmail(user.email, user.username, verifyToken);

    return {
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
      },
    };
  }

  async login(dto: LoginDto): Promise<LoginResponse> {
    const user = await this.usersRepository.findOne({
      where: [{ email: dto.identifier }, { username: dto.identifier }],
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Account is disabled');
    }

    const passwordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const totpSecret = await this.totpSecretsRepository.findOne({
      where: { userId: user.id, isEnabled: true },
    });

    if (totpSecret) {
      const totpChallenge = this.jwtService.sign(
        { sub: user.id, type: 'totp-challenge' },
        { expiresIn: '5m' },
      );

      return { requiresTotp: true, totpChallenge };
    }

    const tokens = await this.generateTokens(user);

    return {
      requiresTotp: false,
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

  async refresh(refreshTokenValue: string): Promise<TokenPair & { user: Partial<User> }> {
    let payload: { sub: string; familyId: string; type: string };
    try {
      payload = this.jwtService.verify(refreshTokenValue, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (payload.type !== 'refresh') {
      throw new UnauthorizedException('Invalid token type');
    }

    const storedTokens = await this.refreshTokensRepository.find({
      where: { familyId: payload.familyId },
      order: { createdAt: 'DESC' },
    });

    if (storedTokens.length === 0) {
      throw new UnauthorizedException('Token family not found');
    }

    const latestToken = storedTokens[0];

    if (latestToken.revoked) {
      await this.refreshTokensRepository.update(
        { familyId: payload.familyId },
        { revoked: true },
      );
      throw new UnauthorizedException('Token reuse detected');
    }

    const isValid = await bcrypt.compare(refreshTokenValue, latestToken.tokenHash);
    if (!isValid) {
      await this.refreshTokensRepository.update(
        { familyId: payload.familyId },
        { revoked: true },
      );
      throw new UnauthorizedException('Token reuse detected');
    }

    latestToken.revoked = true;
    await this.refreshTokensRepository.save(latestToken);

    const user = await this.usersRepository.findOne({
      where: { id: payload.sub },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or disabled');
    }

    const tokens = await this.generateTokens(user, payload.familyId);

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

  async logout(refreshTokenValue: string): Promise<void> {
    try {
      const payload = this.jwtService.verify(refreshTokenValue, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
      });

      await this.refreshTokensRepository.update(
        { familyId: payload.familyId },
        { revoked: true },
      );
    } catch {
      // Silently ignore invalid tokens on logout
    }
  }

  async verifyEmail(token: string): Promise<void> {
    let payload: { sub: string; type: string };
    try {
      payload = this.jwtService.verify(token);
    } catch {
      throw new BadRequestException('Invalid or expired verification token');
    }

    if (payload.type !== 'email-verify') {
      throw new BadRequestException('Invalid token type');
    }

    const user = await this.usersRepository.findOne({
      where: { id: payload.sub },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    user.emailVerified = true;
    await this.usersRepository.save(user);
  }

  async forgotPassword(email: string): Promise<void> {
    const user = await this.usersRepository.findOne({ where: { email } });

    if (!user) {
      return;
    }

    const token = uuidv4();
    const tokenHash = await bcrypt.hash(token, BCRYPT_ROUNDS);

    const passwordReset = this.passwordResetsRepository.create({
      userId: user.id,
      tokenHash,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
    });

    await this.passwordResetsRepository.save(passwordReset);
    await this.mailService.sendPasswordResetEmail(user.email, user.username, token);
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const resets = await this.passwordResetsRepository.find({
      where: { used: false },
      order: { createdAt: 'DESC' },
      take: 20,
    });

    let matchedReset: PasswordReset | null = null;
    for (const reset of resets) {
      if (reset.expiresAt < new Date()) continue;
      const isMatch = await bcrypt.compare(token, reset.tokenHash);
      if (isMatch) {
        matchedReset = reset;
        break;
      }
    }

    if (!matchedReset) {
      throw new BadRequestException('Invalid or expired reset token');
    }

    const user = await this.usersRepository.findOne({
      where: { id: matchedReset.userId },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await this.usersRepository.save(user);

    matchedReset.used = true;
    await this.passwordResetsRepository.save(matchedReset);

    await this.refreshTokensRepository.update(
      { userId: user.id },
      { revoked: true },
    );
  }

  async generateTokens(user: User, familyId?: string): Promise<TokenPair> {
    const tokenFamilyId = familyId || uuidv4();

    const accessToken = this.jwtService.sign({
      sub: user.id,
      username: user.username,
      role: user.role,
      type: 'access',
    });

    const refreshToken = this.jwtService.sign(
      {
        sub: user.id,
        familyId: tokenFamilyId,
        type: 'refresh',
      },
      {
        secret: this.configService.get<string>('jwt.refreshSecret'),
        expiresIn: (this.configService.get<string>('jwt.refreshExpiresIn') || '7d') as any,
      },
    );

    const tokenHash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS);

    const storedToken = this.refreshTokensRepository.create({
      userId: user.id,
      tokenHash,
      familyId: tokenFamilyId,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    await this.refreshTokensRepository.save(storedToken);

    return { accessToken, refreshToken };
  }

  getProfile(user: User): Partial<User> {
    return {
      id: user.id,
      username: user.username,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      emailVerified: user.emailVerified,
      matrixUserId: user.matrixUserId,
      createdAt: user.createdAt,
    };
  }
}
