import { DataSource } from 'typeorm';
import 'dotenv/config';

export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  username: process.env.DB_USERNAME || 'shychedelic',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_DATABASE || 'shychedelic',
  entities: ['src/**/*.entity.ts'],
  migrations: ['src/migrations/*.ts'],
});
