import { z } from 'zod';
import { Account } from '../models/Account.js';
import { Transaction } from '../models/Transaction.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created } from '../utils/respond.js';
import { recomputeAccountBalance, getTotalBalance } from '../services/balance.service.js';
import { defaultsForAccountType } from '../utils/defaults.js';

export const createAccountSchema = z.object({
  name: z.string().min(1, 'Account name is required').max(60),
  type: z.enum(['cash', 'bank', 'wallet', 'card', 'other']).default('cash'),
  icon: z.string().optional(),
  color: z.string().optional(),
  currency: z.string().default('PKR'),
  initialBalance: z.coerce.number().default(0),
});

export const updateAccountSchema = createAccountSchema.partial().extend({
  isArchived: z.boolean().optional(),
});

/** GET /accounts */
export const listAccounts = catchAsync(async (req, res) => {
  const includeArchived = req.query.includeArchived === 'true';
  const accounts = await Account.find({
    user: req.user._id,
    ...(includeArchived ? {} : { isArchived: false }),
  }).sort({ isDefault: -1, createdAt: 1 });

  const totalBalance = accounts
    .filter((a) => !a.isArchived)
    .reduce((sum, a) => sum + a.currentBalance, 0);

  return ok(res, { accounts, totalBalance, currency: req.user.settings.currency });
});

/** GET /accounts/:id */
export const getAccount = catchAsync(async (req, res) => {
  const account = await Account.findOne({ _id: req.params.id, user: req.user._id });
  if (!account) throw ApiError.notFound('Account not found');

  const transactionCount = await Transaction.countDocuments({
    user: req.user._id,
    $or: [{ account: account._id }, { toAccount: account._id }],
  });

  return ok(res, { account, transactionCount });
});

/** POST /accounts */
export const createAccount = catchAsync(async (req, res) => {
  const { name, type, currency, initialBalance, icon, color } = req.body;

  const existing = await Account.findOne({ user: req.user._id, name });
  if (existing) throw ApiError.conflict('You already have an account with that name');

  const isFirst = (await Account.countDocuments({ user: req.user._id })) === 0;
  const typeDefaults = defaultsForAccountType(type);

  const account = await Account.create({
    user: req.user._id,
    name,
    type,
    currency,
    initialBalance,
    currentBalance: initialBalance,
    isDefault: isFirst,
    icon: icon || typeDefaults.icon,
    color: color || typeDefaults.color,
  });

  return created(res, { account }, 'Account added');
});

/** PATCH /accounts/:id */
export const updateAccount = catchAsync(async (req, res) => {
  const account = await Account.findOne({ _id: req.params.id, user: req.user._id });
  if (!account) throw ApiError.notFound('Account not found');

  const balanceChanged =
    req.body.initialBalance !== undefined &&
    req.body.initialBalance !== account.initialBalance;

  Object.assign(account, req.body);
  await account.save();

  // Changing the opening balance shifts every derived balance after it.
  if (balanceChanged) await recomputeAccountBalance(account._id);

  return ok(res, { account: await Account.findById(account._id) }, 'Account updated');
});

/** DELETE /accounts/:id */
export const deleteAccount = catchAsync(async (req, res) => {
  const account = await Account.findOne({ _id: req.params.id, user: req.user._id });
  if (!account) throw ApiError.notFound('Account not found');

  const linked = await Transaction.countDocuments({
    user: req.user._id,
    $or: [{ account: account._id }, { toAccount: account._id }],
  });

  // Deleting an account with history would orphan transactions and break
  // reports, so archive instead and keep the ledger intact.
  if (linked > 0) {
    account.isArchived = true;
    await account.save();
    return ok(res, { account, archived: true },
      `Account has ${linked} transaction(s) so it was archived instead of deleted`);
  }

  await account.deleteOne();
  return ok(res, { archived: false }, 'Account deleted');
});

/** POST /accounts/:id/set-default */
export const setDefaultAccount = catchAsync(async (req, res) => {
  const account = await Account.findOne({ _id: req.params.id, user: req.user._id });
  if (!account) throw ApiError.notFound('Account not found');

  await Account.updateMany({ user: req.user._id }, { $set: { isDefault: false } });
  account.isDefault = true;
  await account.save();

  return ok(res, { account }, `${account.name} is now your default account`);
});

/** GET /accounts/total */
export const totalBalance = catchAsync(async (req, res) =>
  ok(res, { totalBalance: await getTotalBalance(req.user._id) })
);
