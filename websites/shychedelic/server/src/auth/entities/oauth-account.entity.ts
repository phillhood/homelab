import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';

@Entity('oauth_accounts')
@Unique(['provider', 'providerId'])
export class OauthAccount {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.oauthAccounts, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column()
  provider: string;

  @Column({ name: 'provider_id' })
  providerId: string;

  @Column({ name: 'provider_email', nullable: true })
  providerEmail: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
