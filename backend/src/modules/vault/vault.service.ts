import { prisma } from '../../config/db.js';

export class VaultService {
  async findByUser(userId: string) {
    return prisma.vaultItem.findMany({ where: { userId }, orderBy: { updatedAt: 'desc' } });
  }

  async findById(userId: string, id: string) {
    return prisma.vaultItem.findFirst({ where: { id, userId } });
  }

  async create(userId: string, data: any) {
    return prisma.vaultItem.create({
      data: {
        userId,
        itemType: data.item_type || 'PASSWORD',
        title: data.title,
        encryptedPayload: data.encrypted_payload,
        iv: data.iv,
      },
    });
  }

  async update(userId: string, id: string, data: any) {
    return prisma.vaultItem.update({ where: { id, userId }, data });
  }

  async delete(userId: string, id: string) {
    await prisma.vaultItem.deleteMany({ where: { id, userId } });
  }
}
