import { registerAs } from '@nestjs/config';

export default registerAs('mail', () => ({
  resendApiKey: process.env.RESEND_API_KEY || '',
  fromEmail: process.env.MAIL_FROM || 'noreply@shychedelic.com',
  fromName: process.env.MAIL_FROM_NAME || 'shychedelic',
  appUrl: process.env.APP_URL || 'https://shychedelic.com',
}));
