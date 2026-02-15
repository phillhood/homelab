import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private resend: Resend;
  private fromEmail: string;
  private fromName: string;
  private appUrl: string;

  constructor(private configService: ConfigService) {
    const apiKey = this.configService.get<string>('mail.resendApiKey');
    this.resend = new Resend(apiKey || 'placeholder');
    this.fromEmail = this.configService.get<string>('mail.fromEmail') || 'noreply@shychedelic.com';
    this.fromName = this.configService.get<string>('mail.fromName') || 'shychedelic';
    this.appUrl = this.configService.get<string>('mail.appUrl') || 'https://shychedelic.com';
  }

  async sendVerificationEmail(
    email: string,
    username: string,
    token: string,
  ): Promise<void> {
    const verifyUrl = `${this.appUrl}/auth/verify-email?token=${token}`;

    try {
      await this.resend.emails.send({
        from: `${this.fromName} <${this.fromEmail}>`,
        to: email,
        subject: 'Verify your email',
        html: `
          <h2>Welcome to shychedelic, ${username}!</h2>
          <p>Click the link below to verify your email address:</p>
          <p><a href="${verifyUrl}">Verify Email</a></p>
          <p>This link expires in 24 hours.</p>
          <p>If you didn't create an account, you can safely ignore this email.</p>
        `,
      });
    } catch (error) {
      this.logger.error(`Failed to send verification email to ${email}`, error);
    }
  }

  async sendPasswordResetEmail(
    email: string,
    username: string,
    token: string,
  ): Promise<void> {
    const resetUrl = `${this.appUrl}/auth/reset-password?token=${token}`;

    try {
      await this.resend.emails.send({
        from: `${this.fromName} <${this.fromEmail}>`,
        to: email,
        subject: 'Reset your password',
        html: `
          <h2>Password Reset</h2>
          <p>Hi ${username}, we received a request to reset your password.</p>
          <p><a href="${resetUrl}">Reset Password</a></p>
          <p>This link expires in 1 hour.</p>
          <p>If you didn't request this, you can safely ignore this email.</p>
        `,
      });
    } catch (error) {
      this.logger.error(`Failed to send password reset email to ${email}`, error);
    }
  }

  async sendWelcomeEmail(email: string, username: string): Promise<void> {
    try {
      await this.resend.emails.send({
        from: `${this.fromName} <${this.fromEmail}>`,
        to: email,
        subject: 'Welcome to shychedelic!',
        html: `
          <h2>Welcome, ${username}!</h2>
          <p>Your email has been verified and your account is ready.</p>
          <p><a href="${this.appUrl}">Go to shychedelic</a></p>
        `,
      });
    } catch (error) {
      this.logger.error(`Failed to send welcome email to ${email}`, error);
    }
  }
}
