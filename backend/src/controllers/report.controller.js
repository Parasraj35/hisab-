import dayjs from 'dayjs';
import { z } from 'zod';
import { Transaction } from '../models/Transaction.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok } from '../utils/respond.js';
import { streamReportPdf, buildReportCsv } from '../services/pdf.service.js';

export const rangeSchema = z.object({
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  months: z.coerce.number().min(1).max(24).default(6),
});

/** Defaults to the current calendar month, matching the screen's header. */
function resolveRange(query) {
  const from = query.from
    ? dayjs(query.from).startOf('day').toDate()
    : dayjs().startOf('month').toDate();
  const to = query.to
    ? dayjs(query.to).endOf('day').toDate()
    : dayjs().endOf('month').toDate();
  return { from, to };
}

/** Transfers are excluded everywhere — moving your own money is not income or expense. */
const spendMatch = (userId, from, to) => ({
  user: userId,
  date: { $gte: from, $lte: to },
  type: { $in: ['expense', 'income'] },
});

async function categoryBreakdown(userId, from, to, type) {
  const rows = await Transaction.aggregate([
    { $match: { user: userId, date: { $gte: from, $lte: to }, type } },
    {
      $group: {
        _id: '$category',
        total: { $sum: '$amount' },
        count: { $sum: 1 },
      },
    },
    {
      $lookup: {
        from: 'categories',
        localField: '_id',
        foreignField: '_id',
        as: 'category',
      },
    },
    { $unwind: { path: '$category', preserveNullAndEmptyArrays: true } },
    {
      $project: {
        _id: 0,
        categoryId: '$_id',
        name: { $ifNull: ['$category.name', 'Uncategorised'] },
        icon: { $ifNull: ['$category.icon', 'category'] },
        color: { $ifNull: ['$category.color', '#6B7280'] },
        total: 1,
        count: 1,
      },
    },
    { $sort: { total: -1 } },
  ]);

  const grandTotal = rows.reduce((sum, r) => sum + r.total, 0);
  return rows.map((r) => ({
    ...r,
    share: grandTotal > 0 ? r.total / grandTotal : 0,
    percent: grandTotal > 0 ? Math.round((r.total / grandTotal) * 100) : 0,
  }));
}

/**
 * GET /reports/overview
 * Everything screen 17 renders, in one request.
 */
export const overview = catchAsync(async (req, res) => {
  const userId = req.user._id;
  const { from, to } = resolveRange(req.query);

  const [totals, expenseByCategory, incomeByCategory, byAccount] = await Promise.all([
    Transaction.aggregate([
      { $match: spendMatch(userId, from, to) },
      { $group: { _id: '$type', total: { $sum: '$amount' }, count: { $sum: 1 } } },
    ]),
    categoryBreakdown(userId, from, to, 'expense'),
    categoryBreakdown(userId, from, to, 'income'),
    Transaction.aggregate([
      { $match: spendMatch(userId, from, to) },
      {
        $group: {
          _id: { account: '$account', type: '$type' },
          total: { $sum: '$amount' },
        },
      },
      {
        $lookup: {
          from: 'accounts',
          localField: '_id.account',
          foreignField: '_id',
          as: 'account',
        },
      },
      { $unwind: '$account' },
      {
        $group: {
          _id: '$account._id',
          name: { $first: '$account.name' },
          income: {
            $sum: { $cond: [{ $eq: ['$_id.type', 'income'] }, '$total', 0] },
          },
          expense: {
            $sum: { $cond: [{ $eq: ['$_id.type', 'expense'] }, '$total', 0] },
          },
        },
      },
      { $sort: { expense: -1 } },
    ]),
  ]);

  const income = totals.find((t) => t._id === 'income')?.total || 0;
  const expense = totals.find((t) => t._id === 'expense')?.total || 0;
  const transactionCount = totals.reduce((s, t) => s + t.count, 0);
  const days = Math.max(1, dayjs(to).diff(dayjs(from), 'day') + 1);

  return ok(res, {
    currency: req.user.settings.currency,
    range: { from, to, label: dayjs(from).format('MMM D') + ' – ' + dayjs(to).format('MMM D, YYYY') },
    totals: {
      income,
      expense,
      net: income - expense,
      transactionCount,
      // Useful context the raw totals don't give on their own.
      avgDailySpend: expense / days,
      savingsRate: income > 0 ? (income - expense) / income : 0,
    },
    expenseByCategory,
    incomeByCategory,
    byAccount,
  });
});

/**
 * GET /reports/trend?months=6
 * Month-by-month income vs expense for the trend chart.
 */
export const trend = catchAsync(async (req, res) => {
  const months = req.query.months || 6;
  const start = dayjs().subtract(months - 1, 'month').startOf('month');

  const rows = await Transaction.aggregate([
    {
      $match: {
        user: req.user._id,
        date: { $gte: start.toDate(), $lte: dayjs().endOf('month').toDate() },
        type: { $in: ['expense', 'income'] },
      },
    },
    {
      $group: {
        _id: { y: { $year: '$date' }, m: { $month: '$date' }, type: '$type' },
        total: { $sum: '$amount' },
      },
    },
  ]);

  // Fill every month in the window so the chart has no gaps.
  const series = [];
  for (let i = 0; i < months; i++) {
    const point = start.add(i, 'month');
    const y = point.year();
    const m = point.month() + 1;
    const income = rows.find((r) => r._id.y === y && r._id.m === m && r._id.type === 'income')?.total || 0;
    const expense = rows.find((r) => r._id.y === y && r._id.m === m && r._id.type === 'expense')?.total || 0;
    series.push({ label: point.format('MMM'), year: y, month: m, income, expense, net: income - expense });
  }

  return ok(res, { series, currency: req.user.settings.currency });
});

/** Shared by the PDF and CSV writers so both show identical numbers. */
export async function buildReportData(user, query) {
  const { from, to } = resolveRange(query);
  const userId = user._id;

  const [totals, byCategory, transactions] = await Promise.all([
    Transaction.aggregate([
      { $match: spendMatch(userId, from, to) },
      { $group: { _id: '$type', total: { $sum: '$amount' } } },
    ]),
    categoryBreakdown(userId, from, to, 'expense'),
    Transaction.find({ user: userId, date: { $gte: from, $lte: to } })
      .populate('account', 'name')
      .populate('toAccount', 'name')
      .populate('category', 'name')
      .sort({ date: -1 })
      .limit(500),
  ]);

  const income = totals.find((t) => t._id === 'income')?.total || 0;
  const expense = totals.find((t) => t._id === 'expense')?.total || 0;

  return {
    user,
    range: { from, to },
    currency: user.settings.currency,
    income,
    expense,
    net: income - expense,
    byCategory,
    transactions,
  };
}

// --- Export -----------------------------------------------------------------

export const exportSchema = z.object({
  format: z.enum(['pdf', 'csv']).default('pdf'),
  type: z.enum(['summary', 'detailed']).default('summary'),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
});

/**
 * GET /reports/export?format=pdf&type=detailed
 * Streams the file directly rather than storing it — nothing to clean up,
 * and the numbers are always current at the moment of download.
 */
export const exportReport = catchAsync(async (req, res) => {
  const { format, type } = req.query;
  const data = await buildReportData(req.user, req.query);

  const stamp = dayjs(data.range.from).format('MMM_YYYY');
  const filename = `Report_${stamp}.${format}`;

  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

  if (format === 'csv') {
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    return res.send(buildReportCsv(data));
  }

  res.setHeader('Content-Type', 'application/pdf');
  return streamReportPdf(res, data, { detailed: type === 'detailed' });
});
