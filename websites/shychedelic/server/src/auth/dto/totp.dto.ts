import { IsString, Length } from 'class-validator';

export class TotpVerifyDto {
  @IsString()
  @Length(6, 6)
  code: string;
}

export class TotpEnableDto {
  @IsString()
  @Length(6, 6)
  code: string;
}

export class TotpDisableDto {
  @IsString()
  password: string;
}

export class TotpLoginVerifyDto {
  @IsString()
  totpChallenge: string;

  @IsString()
  @Length(6, 6)
  code: string;
}
