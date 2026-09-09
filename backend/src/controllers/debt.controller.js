import mongoose from 'mongoose';
import { z } from 'zod';
import { Debt } from '../models/Debt.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created } from '../utils/respond.js';
import { pushNotification } from '../services/notification.service.js';

const objectId = z.string().refine(mongoose.isValidObjectId, 'Invalid id');

export const createDebtSchema = z.object({
  direction: z.enum(['lent', 'borrowed']),
  personName: z.string().min(1, 'Person name is required').max(60),
  personPhone: z.string().max(20).optional().default(''),
  amount: z.coerce.number().finite('Enter a valid amount').positive('Amount must be greater than zero'),
  account: objectId.optional().nullable(),
  dueDate: z.coerce.date().optional().nullable(),
  note: z.string().max(200).optional().default(''),
});

export const updateDebtSchema = createDebtSchema.partial();

export const settlementSchema = z.object({
  amount: z.coerce.number().finite('Enter a valid amount').positive('Amount must be greater than zero'),
  date: z.coerce.date().default(() => new Date()),
  note: z.string().max(200).optional().default(''),
});

/**
 * GET /debts?direction=lent
 * Returns the list plus the header totals the screen shows.
 */
export const listDebts = catchAsync(async (req, res) => {
  const { direction, status } = req.query;

  const filter = {
    user: req.user._id,
    ...(direction ? { direction } : {}),
    ...(status ? { status } : {}),
  };

  const debts = await Debt.find(filter)
    .populate('account', 'name icon type')
    .sort({ status: 1, dueDate: 1, createdAt: -1 });

  // Totals are computed per direction so both tabs can render from one call.
  const [totals] = await Debt.aggregate([
    { $match: { user: req.user._id } },
    {
      $group: {
        _id: '$direction',
        total: { $sum: '$amount' },
        settled: { $sum: '$settledAmount' },
      },
    },
    {
      $group: {
        _id: null,
        rows: { $push: { direction: '$_id', total: '$total', settled: '$settled' } },
      },
    },
  ]);

  const rows = totals?.rows || [];
  const lent = rows.find((r) => r.direction === 'lent') || { total: 0, settled: 0 };
  const borrowed = rows.find((r) => r.direction === 'borrowed') || { total: 0, settled: 0 };

  return ok(res, {
    debts,
    currency: req.user.settings.currency,
    summary: {
      lent: {
        total: lent.total,
        received: lent.settled,
        outstanding: lent.total - lent.settled,
      },
      borrowed: {
        total: borrowed.total,
        repaid: borrowed.settled,
        outstanding: borrowed.total - borrowed.settled,
      },
    },
  });
});

/** GET /debts/:id */
export const getDebt = catchAsync(async (req, res) => {
  const debt = await Debt.findOne({ _id: req.params.id, user: req.user._id })
    .populate('account', 'name icon type');
  if (!debt) throw ApiError.notFound('Record not found');
  return ok(res, { debt });
});

/** POST /debts */
export const createDebt = catchAsync(async (req, res) => {
  const debt = await Debt.create({ ...req.body, user: req.user._id });

  await pushNotification(req.user._id, {
    type: 'debt_reminder',
    title: req.body.direction === 'lent' ? 'Loan Recorded' : 'Borrowing Recorded',
    body: `${req.body.personName} · ${req.user.settings.currency} ${req.body.amount}`,
    meta: { debtId: debt._id },
  });

  return created(res, { debt }, 'Record saved');
});

/** PATCH /debts/:id */
export const updateDebt = catchAsync(async (req, res) => {
  const debt = await Debt.findOne({ _id: req.params.id, user: req.user._id });
  if (!debt) throw ApiError.notFound('Record not found');

  Object.assign(debt, req.body);
  debt.recalculateStatus();
  await debt.save();

  return ok(res, { debt }, 'Record updated');
});

/** DELETE /debts/:id */
export const deleteDebt = catchAsync(async (req, res) => {
  const debt = await Debt.findOneAndDelete({ _id: req.params.id, user: req.user._id });
  if (!debt) throw ApiError.notFound('Record not found');
  return ok(res, {}, 'Record deleted');
});

/**
 * POST /debts/:id/settle
 * Records a part or full repayment. Over-payment is rejected rather than
 * silently clamped, so the numbers always reconcile.
 */
export const settleDebt = catchAsync(async (req, res) => {
  const debt = await Debt.findOne({ _id: req.params.id, user: req.user._id });
  if (!debt) throw ApiError.notFound('Record not found');
  if (debt.status === 'paid') throw ApiError.badRequest('This record is already settled');

  const outstanding = debt.amount - debt.settledAmount;
  if (req.body.amount > outstanding) {
    throw ApiError.badRequest(
      `Only ${outstanding.toFixed(2)} is outstanding on this record`
    );
  }

  debt.settlements.push(req.body);
  debt.recalculateStatus();
  await debt.save();

  if (debt.status === 'paid') {
    await pushNotification(req.user._id, {
      type: 'debt_reminder',
      title: 'Record Settled',
      body: `${debt.personName} is fully settled`,
      meta: { debtId: debt._id },
    });
  }

  return ok(res, { debt }, 'Payment recorded');
});

/** DELETE /debts/:id/settle/:settlementId — undo a mis-entered payment */
export const removeSettlement = catchAsync(async (req, res) => {
  const debt = await Debt.findOne({ _id: req.params.id, user: req.user._id });
  if (!debt) throw ApiError.notFound('Record not found');

  const entry = debt.settlements.id(req.params.settlementId);
  if (!entry) throw ApiError.notFound('Payment entry not found');

  entry.deleteOne();
  debt.recalculateStatus();
  await debt.save();

  return ok(res, { debt }, 'Payment removed');
});
