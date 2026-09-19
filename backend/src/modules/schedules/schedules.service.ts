import { prisma } from '../../config/db.js';

export class SchedulesService {
  async findByUser(userId: string) {
    return prisma.studySchedule.findMany({ where: { userId }, orderBy: { startTime: 'asc' } });
  }

  async create(userId: string, data: any) {
    return prisma.studySchedule.create({
      data: {
        userId,
        label: data.label || data.title,
        startTime: new Date(data.start_time),
        endTime: new Date(data.end_time),
        daysOfWeek: data.days_of_week || [],
        blockedApps: data.blocked_apps || [],
      },
    });
  }

  async update(userId: string, id: string, data: any) {
    return prisma.studySchedule.update({ where: { id, userId }, data });
  }

  async delete(userId: string, id: string) {
    await prisma.studySchedule.deleteMany({ where: { id, userId } });
  }
}
