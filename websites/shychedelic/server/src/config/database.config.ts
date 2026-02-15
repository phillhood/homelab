import { registerAs } from '@nestjs/config';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';

export default registerAs(
  'database',
  (): TypeOrmModuleOptions => ({
    type: 'postgres',
    host: process.env.DB_HOST || 'postgres.databases.svc.cluster.local',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    username: process.env.DB_USERNAME || 'shychedelic',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'shychedelic',
    autoLoadEntities: true,
    synchronize: false,
    migrationsRun: true,
    migrations: [__dirname + '/../migrations/*{.ts,.js}'],
    logging: process.env.NODE_ENV !== 'production',
  }),
);
