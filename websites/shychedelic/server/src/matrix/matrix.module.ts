import { Module } from '@nestjs/common';
import { MatrixController } from './matrix.controller';
import { MatrixService } from './matrix.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [MatrixController],
  providers: [MatrixService],
})
export class MatrixModule {}
