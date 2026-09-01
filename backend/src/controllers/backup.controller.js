import { Backup } from '../models/Backup.js';
import { Account } from '../models/Account.js';
import { Category } from '../models/Category.js';
import { Transaction } from '../models/Transaction.js';
import { Debt } from '../models/Debt.js';
import { SavingsGoal } from '../models/SavingsGoal.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created } from '../utils/respond.js';
import { pushNotification } from '../services/notification.service.js';

/** GET /backups — metadata only; payloads are excluded by the schema. */
export const list = catchAsync(async (req, res) => {
  const backups = await Backup.find({ user: req.user._id })
    .sort({ createdAt: -1 })
    .limit(20);
  return ok(res, { backups, latest: backups[0] || null });
});

/** POST /backups — snapshot everything the user owns. */
export const create = catchAsync(async (req, res) => {
  const userId = req.user._id;

  const [accounts, categories, transactions, debts, goals] = await Promise.all([
    Account.find({ user: userId }).lean(),
    Category.find({ user: userId }).lean(),
    Transaction.find({ user: userId }).lean(),
    Debt.find({ user: userId }).lean(),
    SavingsGoal.find({ user: userId }).lean(),
  ]);

  const payload = {
    version: 1,
    createdAt: new Date(),
    settings: req.user.settings,
    accounts,
    categories,
    transactions,
    debts,
    savingsGoals: goals,
  };

  const counts = {
    accounts: accounts.length,
    categories: categories.length,
    transactions: transactions.length,
    debts: debts.length,
    savingsGoals: goals.length,
  };

  const backup = await Backup.create({
    user: userId,
    payload,
    counts,
    sizeBytes: Buffer.byteLength(JSON.stringify(payload)),
  });

  // Keep only the 10 most recent so the collection can't grow without bound.
  const stale = await Backup.find({ user: userId })
    .sort({ createdAt: -1 })
    .skip(10)
    .select('_id');
  if (stale.length > 0) {
    await Backup.deleteMany({ _id: { $in: stale.map((b) => b._id) } });
  }

  await pushNotification(userId, {
    type: 'backup',
    title: 'Backup Completed',
    body: `${counts.transactions} transactions backed up successfully`,
    meta: { backupId: backup._id },
  });

  return created(
    res,
    { backup: { _id: backup._id, counts, sizeBytes: backup.sizeBytes, createdAt: backup.createdAt } },
    'Backup created'
  );
});

/**
 * POST /backups/:id/restore
 * Replaces current data with the snapshot. Destructive by design — the client
 * confirms first, and a safety backup is taken before anything is deleted.
 */
export const restore = catchAsync(async (req, res) => {
  const userId = req.user._id;

  const backup = await Backup.findOne({ _id: req.params.id, user: userId })
    .select('+payload');
  if (!backup) throw ApiError.notFound('Backup not found');

  const { payload } = backup;
  if (!payload || payload.version !== 1) {
    throw ApiError.badRequest('This backup format is not supported');
  }

  // Snapshot current state first so a restore is itself undoable.
  const [accounts, categories, transactions, debts, goals] = await Promise.all([
    Account.find({ user: userId }).lean(),
    Category.find({ user: userId }).lean(),
    Transaction.find({ user: userId }).lean(),
    Debt.find({ user: userId }).lean(),
    SavingsGoal.find({ user: userId }).lean(),
  ]);
  await Backup.create({
    user: userId,
    payload: { version: 1, createdAt: new Date(), settings: req.user.settings,
      accounts, categories, transactions, debts, savingsGoals: goals },
    counts: { accounts: accounts.length, categories: categories.length,
      transactions: transactions.length, debts: debts.length, savingsGoals: goals.length },
    sizeBytes: 0,
  });

  await Promise.all([
    Account.deleteMany({ user: userId }),
    Category.deleteMany({ user: userId }),
    Transaction.deleteMany({ user: userId }),
    Debt.deleteMany({ user: userId }),
    SavingsGoal.deleteMany({ user: userId }),
  ]);

  const insert = (Model, docs) =>
    docs?.length ? Model.insertMany(docs, { ordered: false }) : Promise.resolve([]);

  await Promise.all([
    insert(Account, payload.accounts),
    insert(Category, payload.categories),
    insert(Transaction, payload.transactions),
    insert(Debt, payload.debts),
    insert(SavingsGoal, payload.savingsGoals),
  ]);

  if (payload.settings) {
    req.user.settings = { ...req.user.settings.toObject(), ...payload.settings };
    await req.user.save();
  }

  return ok(res, { restored: backup.counts }, 'Backup restored');
});

/** DELETE /backups/:id */
export const remove = catchAsync(async (req, res) => {
  const deleted = await Backup.findOneAndDelete({
    _id: req.params.id,
    user: req.user._id,
  });
  if (!deleted) throw ApiError.notFound('Backup not found');
  return ok(res, {}, 'Backup deleted');
});
