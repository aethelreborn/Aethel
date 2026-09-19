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

  // Whitelist: only allow label, start_time, end_time, days_of_week, blocked_apps
  async update(userId: string, id: string, data: any) {
    const { label, start_time, end_time, days_of_week, blocked_apps } = data;
    return prisma.studySchedule.update({
      where: { id, userId },
      data: {
        ...(label !== undefined && { label }),
        ...(start_time !== undefined && { startTime: new Date(start_time) }),
        ...(end_time !== undefined && { endTime: new Date(end_time) }),
        ...(days_of_week !== undefined && { daysOfWeek: days_of_week }),
        ...(blocked_apps !== undefined && { blockedApps: blocked_apps }),
      },
    });
  }

  async delete(userId: string, id: string) {
    await prisma.studySchedule.deleteMany({ where: { id, userId } });
  }
}
