import { Injectable, Logger, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../auth/entities/user.entity';

interface SynapseLoginResponse {
  access_token: string;
}

interface LoginTokenResponse {
  login_token: string;
  expires_in_ms: number;
}

@Injectable()
export class MatrixService {
  private readonly logger = new Logger(MatrixService.name);
  private synapseUrl: string;
  private serverName: string;
  private adminToken: string;
  private elementUrl: string;

  constructor(
    private configService: ConfigService,
    @InjectRepository(User) private usersRepository: Repository<User>,
  ) {
    this.synapseUrl = this.configService.get<string>('matrix.synapseUrl') || '';
    this.serverName = this.configService.get<string>('matrix.serverName') || '';
    this.adminToken = this.configService.get<string>('matrix.adminToken') || '';
    this.elementUrl = this.configService.get<string>('matrix.elementUrl') || '';
  }

  async getLoginToken(
    user: User,
  ): Promise<{ loginToken: string; elementUrl: string }> {
    const matrixUserId = `@${user.username}:${this.serverName}`;

    await this.ensureMatrixUser(user, matrixUserId);

    const userAccessToken = await this.getUserAccessToken(matrixUserId);

    const loginToken = await this.generateLoginToken(userAccessToken);

    return {
      loginToken,
      elementUrl: `${this.elementUrl}?loginToken=${loginToken}`,
    };
  }

  private async ensureMatrixUser(
    user: User,
    matrixUserId: string,
  ): Promise<void> {
    const url = `${this.synapseUrl}/_synapse/admin/v2/users/${encodeURIComponent(matrixUserId)}`;

    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${this.adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        displayname: user.displayName || user.username,
        admin: false,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      this.logger.error(`Failed to ensure Matrix user ${matrixUserId}: ${error}`);
      throw new InternalServerErrorException('Failed to provision Matrix user');
    }

    if (!user.matrixUserId) {
      user.matrixUserId = matrixUserId;
      await this.usersRepository.save(user);
    }
  }

  private async getUserAccessToken(matrixUserId: string): Promise<string> {
    const url = `${this.synapseUrl}/_synapse/admin/v1/users/${encodeURIComponent(matrixUserId)}/login`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });

    if (!response.ok) {
      const error = await response.text();
      this.logger.error(`Failed to get access token for ${matrixUserId}: ${error}`);
      throw new InternalServerErrorException('Failed to get Matrix access token');
    }

    const data = (await response.json()) as SynapseLoginResponse;
    return data.access_token;
  }

  private async generateLoginToken(accessToken: string): Promise<string> {
    const url = `${this.synapseUrl}/_matrix/client/v1/login/get_token`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });

    if (!response.ok) {
      const error = await response.text();
      this.logger.error(`Failed to generate login token: ${error}`);
      throw new InternalServerErrorException('Failed to generate Matrix login token');
    }

    const data = (await response.json()) as LoginTokenResponse;
    return data.login_token;
  }
}
