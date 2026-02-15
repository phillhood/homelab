import { registerAs } from '@nestjs/config';

export default registerAs('jwt', () => ({
  secret: process.env.JWT_SECRET || 'dev-jwt-secret',
  refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev-jwt-refresh-secret',
  accessExpiresIn: '15m',
  refreshExpiresIn: '7d',
}));
