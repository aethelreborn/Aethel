import { prisma } from '../../config/db.js';
import { syncGateway } from '../../websocket/syncGateway.js';

export class VaultService {
  async findByUser(userId: string) {
    return prisma.vaultItem.findMany({ where: { userId }, orderBy: { updatedAt: 'desc' } });
  }

  async findById(userId: string, id: string) {
    return prisma.vaultItem.findFirst({ where: { id, userId } });
  }

  async create(userId: string, data: any) {
    const item = await prisma.vaultItem.create({
      data: {
        userId,
        itemType: data.item_type || 'PASSWORD',
        title: data.title,
        encryptedPayload: data.encrypted_payload,
        iv: data.iv,
      },
    });
    syncGateway.broadcast(userId, 'vault.created', item);
    return item;
  }

  async update(userId: string, id: string, data: any) {
    const item = await prisma.vaultItem.update({ where: { id, userId }, data });
    syncGateway.broadcast(userId, 'vault.updated', item);
    return item;
  }

  async delete(userId: string, id: string) {
    await prisma.vaultItem.deleteMany({ where: { id, userId } });
    syncGateway.broadcast(userId, 'vault.deleted', { id });
  }
}
