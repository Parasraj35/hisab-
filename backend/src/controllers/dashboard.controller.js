import dayjs from 'dayjs';
import { Account } from '../models/Account.js';
import { Transaction } from '../models/Transaction.js';
import { Notification } from '../models/Notification.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok } from '../utils/respond.js';

/**
 * GET /dashboard/overview
 * Single call powering screen 7 — avoids four round-trips on app open.
 */
export const overview = catchAsync(async (req, res) => {
  const userId = req.user._id;
  const monthStart = dayjs().startOf('month').toDate();
  const monthEnd = dayjs().endOf('month').toDate();

  const [accounts, monthRows, recent, unreadCount] = await Promise.all([
    Account.find({ user: userId, isArchived: false }).sort({ isDefault: -1, createdAt: 1 }),
    Transaction.aggregate([
      { $match: { user: userId, date: { $gte: monthStart, $lte: monthEnd },
        type: { $in: ['expense', 'income'] } } },
      { $group: { _id: '$type', total: { $sum: '$amount' } } },
    ]),
    Transaction.find({ user: userId })
      .populate('account', 'name icon type')
      .populate('category', 'name icon color')
      .sort({ date: -1, createdAt: -1 })
      .limit(5),
    Notification.countDocuments({ user: userId, isRead: false }),
  ]);

  const income = monthRows.find((r) => r._id === 'income')?.total || 0;
  const expense = monthRows.find((r) => r._id === 'expense')?.total || 0;
  const totalBalance = accounts.reduce((sum, a) => sum + a.currentBalance, 0);

  return ok(res, {
    currency: req.user.settings.currency,
    totalBalance,
    accounts,
    thisMonth: {
      label: dayjs().format('MMMM YYYY'),
      income,
      expense,
      net: income - expense,
    },
    recentTransactions: recent,
    unreadNotifications: unreadCount,
  });
});
