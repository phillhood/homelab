import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema1739577600000 implements MigrationInterface {
  name = 'InitialSchema1739577600000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    await queryRunner.query(`
      CREATE TYPE "users_role_enum" AS ENUM ('admin', 'user')
    `);

    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "username" character varying NOT NULL,
        "email" character varying NOT NULL,
        "password_hash" character varying NOT NULL,
        "display_name" character varying,
        "role" "users_role_enum" NOT NULL DEFAULT 'user',
        "email_verified" boolean NOT NULL DEFAULT false,
        "is_active" boolean NOT NULL DEFAULT true,
        "matrix_user_id" character varying,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_users_username" UNIQUE ("username"),
        CONSTRAINT "UQ_users_email" UNIQUE ("email"),
        CONSTRAINT "PK_users" PRIMARY KEY ("id")
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "refresh_tokens" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "token_hash" character varying NOT NULL,
        "family_id" uuid NOT NULL,
        "expires_at" TIMESTAMP NOT NULL,
        "revoked" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_refresh_tokens" PRIMARY KEY ("id"),
        CONSTRAINT "FK_refresh_tokens_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "totp_secrets" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "secret" character varying NOT NULL,
        "is_enabled" boolean NOT NULL DEFAULT false,
        "backup_codes" text[] NOT NULL DEFAULT '{}',
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_totp_secrets_user_id" UNIQUE ("user_id"),
        CONSTRAINT "PK_totp_secrets" PRIMARY KEY ("id"),
        CONSTRAINT "FK_totp_secrets_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "password_resets" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "token_hash" character varying NOT NULL,
        "expires_at" TIMESTAMP NOT NULL,
        "used" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_password_resets" PRIMARY KEY ("id"),
        CONSTRAINT "FK_password_resets_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "invite_codes" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "code" character varying NOT NULL,
        "created_by" uuid,
        "max_uses" integer NOT NULL DEFAULT 1,
        "use_count" integer NOT NULL DEFAULT 0,
        "expires_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_invite_codes_code" UNIQUE ("code"),
        CONSTRAINT "PK_invite_codes" PRIMARY KEY ("id"),
        CONSTRAINT "FK_invite_codes_creator" FOREIGN KEY ("created_by")
          REFERENCES "users"("id")
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "oauth_accounts" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "provider" character varying NOT NULL,
        "provider_id" character varying NOT NULL,
        "provider_email" character varying,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_oauth_accounts_provider_provider_id" UNIQUE ("provider", "provider_id"),
        CONSTRAINT "PK_oauth_accounts" PRIMARY KEY ("id"),
        CONSTRAINT "FK_oauth_accounts_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`CREATE INDEX "IDX_refresh_tokens_user_id" ON "refresh_tokens" ("user_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_refresh_tokens_family_id" ON "refresh_tokens" ("family_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_password_resets_user_id" ON "password_resets" ("user_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_oauth_accounts_user_id" ON "oauth_accounts" ("user_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_oauth_accounts_user_id"`);
    await queryRunner.query(`DROP INDEX "IDX_password_resets_user_id"`);
    await queryRunner.query(`DROP INDEX "IDX_refresh_tokens_family_id"`);
    await queryRunner.query(`DROP INDEX "IDX_refresh_tokens_user_id"`);
    await queryRunner.query(`DROP TABLE "oauth_accounts"`);
    await queryRunner.query(`DROP TABLE "invite_codes"`);
    await queryRunner.query(`DROP TABLE "password_resets"`);
    await queryRunner.query(`DROP TABLE "totp_secrets"`);
    await queryRunner.query(`DROP TABLE "refresh_tokens"`);
    await queryRunner.query(`DROP TABLE "users"`);
    await queryRunner.query(`DROP TYPE "users_role_enum"`);
  }
}
