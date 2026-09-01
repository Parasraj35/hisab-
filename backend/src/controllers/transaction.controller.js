import mongoose from 'mongoose';
import { z } from 'zod';
import dayjs from 'dayjs';
import { Transaction } from '../models/Transaction.js';
import { Account } from '../models/Account.js';
import { Category } from '../models/Category.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created, paginated } from '../utils/respond.js';
import { recomputeAccounts } from '../services/balance.service.js';
import { pushNotification } from '../services/notification.service.js';

const objectId = z.string().refine(mongoose.isValidObjectId, 'Invalid id');

export const createTransactionSchema = z
  .object({
    type: z.enum(['expense', 'income', 'transfer']),
    amount: z.coerce.number().positive('Amount must be greater than zero'),
    account: objectId,
    toAccount: objectId.optional().nullable(),
    category: objectId.optional().nullable(),
    date: z.coerce.date().default(() => new Date()),
    note: z.string().max(200).optional().default(''),
  })
  .superRefine((data, ctx) => {
    if (data.type === 'transfer') {
      if (!data.toAccount) {
        ctx.addIssue({ code: 'custom', path: ['toAccount'],
          message: 'Destination account is required for a transfer' });
      } else if (data.toAccount === data.account) {
        ctx.addIssue({ code: 'custom', path: ['toAccount'],
          message: 'Choose a different destination account' });
      }
    } else if (!data.category) {
      ctx.addIssue({ code: 'custom', path: ['category'],
        message: 'Category is required' });
    }
  });

export const updateTransactionSchema = z.object({
  amount: z.coerce.number().positive().optional(),
  account: objectId.optional(),
  toAccount: objectId.optional().nullable(),
  category: objectId.optional().nullable(),
  date: z.coerce.date().optional(),
  note: z.string().max(200).optional(),
});

export const listQuerySchema = z.object({
  type: z.enum(['expense', 'income', 'transfer']).optional(),
  account: objectId.optional(),
  category: objectId.optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  search: z.string().optional(),
  minAmount: z.coerce.number().optional(),
  maxAmount: z.coerce.number().optional(),
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(20),
});

/** Verifies every referenced account/category belongs to the caller. */
async function assertOwnership(userId, { account, toAccount, category }) {
  const ids = [account, toAccount].filter(Boolean);
  const accounts = await Account.find({ _id: { $in: ids }, user: userId });
  if (accounts.length !== new Set(ids.map(String)).size) {
    throw ApiError.badRequest('One of the selected accounts does not exist');
  }
  if (category) {
    const cat = await Category.findOne({ _id: category, user: userId });
    if (!cat) throw ApiError.badRequest('Selected category does not exist');
  }
}

function buildFilter(userId, q) {
  const filter = { user: userId };
  if (q.type) filter.type = q.type;
  if (q.account) filter.$or = [{ account: q.account }, { toAccount: q.account }];
  if (q.category) filter.category = q.category;
  if (q.from || q.to) {
    filter.date = {};
    if (q.from) filter.date.$gte = dayjs(q.from).startOf('day').toDate();
    if (q.to) filter.date.$lte = dayjs(q.to).endOf('day').toDate();
  }
  if (q.minAmount !== undefined || q.maxAmount !== undefined) {
    filter.amount = {};
    if (q.minAmount !== undefined) filter.amount.$gte = q.minAmount;
    if (q.maxAmount !== undefined) filter.amount.$lte = q.maxAmount;
  }
  if (q.search) filter.note = { $regex: q.search, $options: 'i' };
  return filter;
}

/** GET /transactions */
export const listTransactions = catchAsync(async (req, res) => {
  const q = req.query;
  const filter = buildFilter(req.user._id, q);
  const skip = (q.page - 1) * q.limit;

  const [items, total] = await Promise.all([
    Transaction.find(filter)
      .populate('account', 'name icon type color')
      .populate('toAccount', 'name icon type color')
      .populate('category', 'name icon color type')
      .sort({ date: -1, createdAt: -1 })
      .skip(skip)
      .limit(q.limit),
    Transaction.countDocuments(filter),
  ]);

  return paginated(res, items, { page: q.page, limit: q.limit, total });
});

/** GET /transactions/:id */
export const getTransaction = catchAsync(async (req, res) => {
  const transaction = await Transaction.findOne({ _id: req.params.id, user: req.user._id })
    .populate('account', 'name icon type color')
    .populate('toAccount', 'name icon type color')
    .populate('category', 'name icon color type');
  if (!transaction) throw ApiError.notFound('Transaction not found');

  return ok(res, { transaction });
});

/** POST /transactions */
export const createTransaction = catchAsync(async (req, res) => {
  const body = req.body;
  await assertOwnership(req.user._id, body);

  const transaction = await Transaction.create({
    ...body,
    user: req.user._id,
    category: body.type === 'transfer' ? null : body.category,
    toAccount: body.type === 'transfer' ? body.toAccount : null,
    transferGroup: body.type === 'transfer' ? new mongoose.Types.ObjectId().toString() : null,
  });

  await recomputeAccounts([transaction.account, transaction.toAccount]);

  const populated = await Transaction.findById(transaction._id)
    .populate('account', 'name icon type color')
    .populate('toAccount', 'name icon type color')
    .populate('category', 'name icon color type');

  if (body.type !== 'transfer') {
    const label = body.type === 'expense' ? 'Expense Added' : 'Income Added';
    const verb = body.type === 'expense' ? 'expense' : 'income';
    await pushNotification(req.user._id, {
      type: body.type,
      title: label,
      body: `You added a new ${verb} of ${req.user.settings.currency} ${body.amount}`,
      meta: { transactionId: transaction._id },
    });
  }

  return created(res, { transaction: populated }, 'Transaction saved');
});

/** PATCH /transactions/:id */
export const updateTransaction = catchAsync(async (req, res) => {
  const transaction = await Transaction.findOne({ _id: req.params.id, user: req.user._id });
  if (!transaction) throw ApiError.notFound('Transaction not found');

  const previousAccounts = [transaction.account, transaction.toAccount];
  await assertOwnership(req.user._id, { ...transaction.toObject(), ...req.body });

  Object.assign(transaction, req.body);
  await transaction.save();

  // Recompute both the old and new accounts — an edit can move money between them.
  await recomputeAccounts([...previousAccounts, transaction.account, transaction.toAccount]);

  const populated = await Transaction.findById(transaction._id)
    .populate('account', 'name icon type color')
    .populate('toAccount', 'name icon type color')
    .populate('category', 'name icon color type');

  return ok(res, { transaction: populated }, 'Transaction updated');
});

/** DELETE /transactions/:id */
export const deleteTransaction = catchAsync(async (req, res) => {
  const transaction = await Transaction.findOne({ _id: req.params.id, user: req.user._id });
  if (!transaction) throw ApiError.notFound('Transaction not found');

  const affected = [transaction.account, transaction.toAccount];
  await transaction.deleteOne();
  await recomputeAccounts(affected);

  return ok(res, {}, 'Transaction deleted');
});

/** GET /transactions/summary?from=&to= */
export const summary = catchAsync(async (req, res) => {
  const from = req.query.from
    ? dayjs(req.query.from).startOf('day').toDate()
    : dayjs().startOf('month').toDate();
  const to = req.query.to
    ? dayjs(req.query.to).endOf('day').toDate()
    : dayjs().endOf('month').toDate();

  const rows = await Transaction.aggregate([
    { $match: { user: req.user._id, date: { $gte: from, $lte: to },
      type: { $in: ['expense', 'income'] } } },
    { $group: { _id: '$type', total: { $sum: '$amount' }, count: { $sum: 1 } } },
  ]);

  const income = rows.find((r) => r._id === 'income')?.total || 0;
  const expense = rows.find((r) => r._id === 'expense')?.total || 0;

  return ok(res, {
    range: { from, to },
    income,
    expense,
    net: income - expense,
    count: rows.reduce((s, r) => s + r.count, 0),
  });
});
