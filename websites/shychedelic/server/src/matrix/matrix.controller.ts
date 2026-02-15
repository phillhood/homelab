import { Controller, Post, UseGuards } from '@nestjs/common';
import { MatrixService } from './matrix.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../auth/entities/user.entity';

@Controller('matrix')
export class MatrixController {
  constructor(private matrixService: MatrixService) {}

  @Post('login-token')
  @UseGuards(JwtAuthGuard)
  async getLoginToken(@CurrentUser() user: User) {
    return this.matrixService.getLoginToken(user);
  }
}
