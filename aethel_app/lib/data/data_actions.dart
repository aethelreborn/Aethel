import '../core/network/sync_service.dart';
import '../core/storage/local_store.dart';
import 'models.dart';

class DataActions {
  final LocalStore _local = LocalStore.instance;

  Future<VaultItem> saveVault(VaultItem item) async {
    final now = DateTime.now();
    final saved = item.copyWith(pending: true, updatedAt: now);
    final snapshot = _local.snapshot;
    final index = snapshot.vault.indexWhere((entry) => entry.id == saved.id);
    if (index == -1) {
      snapshot.vault.add(saved);
    } else {
      snapshot.vault[index] = saved;
    }
    await _local.save();
    SyncService.instance.notifyLocalChange();
    return saved;
  }

  Future<void> deleteVault(String id) async {
    final snapshot = _local.snapshot;
    snapshot.vault.removeWhere((item) => item.id == id);
    if (!snapshot.deletedVaultIds.contains(id)) {
      snapshot.deletedVaultIds.add(id);
    }
    await _local.save();
    SyncService.instance.notifyLocalChange();
  }

  Future<BillItem> saveBill(BillItem bill) async {
    final now = DateTime.now();
    final saved = bill.copyWith(pending: true, updatedAt: now);
    final snapshot = _local.snapshot;
    final index = snapshot.bills.indexWhere((entry) => entry.id == saved.id);
    if (index == -1) {
      snapshot.bills.add(saved);
    } else {
      snapshot.bills[index] = saved;
    }
    await _local.save();
    SyncService.instance.notifyLocalChange();
    return saved;
  }

  Future<BillItem> markBillPaid(BillItem bill) async {
    final now = DateTime.now();
    final next = bill.cycle?.advance(bill.nextDueDate ?? now);
    final saved = bill.copyWith(
      nextDueDate: next,
      lastPaidAt: now,
      isActive: bill.cycle == null ? false : bill.isActive,
      pending: true,
      updatedAt: now,
    );
    return saveBill(saved);
  }

  Future<void> deleteBill(String id) async {
    final snapshot = _local.snapshot;
    snapshot.bills.removeWhere((item) => item.id == id);
    if (!snapshot.deletedBillIds.contains(id)) {
      snapshot.deletedBillIds.add(id);
    }
    await _local.save();
    SyncService.instance.notifyLocalChange();
  }

  Future<FocusSchedule> saveSchedule(FocusSchedule schedule) async {
    final now = DateTime.now();
    final saved = schedule.copyWith(pending: true, updatedAt: now);
    final snapshot = _local.snapshot;
    final index =
        snapshot.schedules.indexWhere((entry) => entry.id == saved.id);
    if (index == -1) {
      snapshot.schedules.add(saved);
    } else {
      snapshot.schedules[index] = saved;
    }
    await _local.save();
    SyncService.instance.notifyLocalChange();
    return saved;
  }

  Future<FocusSchedule> toggleSchedule(FocusSchedule schedule) async {
    return saveSchedule(schedule.copyWith(enabled: !schedule.enabled));
  }

  Future<void> deleteSchedule(String id) async {
    final snapshot = _local.snapshot;
    snapshot.schedules.removeWhere((item) => item.id == id);
    if (!snapshot.deletedScheduleIds.contains(id)) {
      snapshot.deletedScheduleIds.add(id);
    }
    await _local.save();
    SyncService.instance.notifyLocalChange();
  }

  Future<void> syncNow() => SyncService.instance.syncNow();
}
