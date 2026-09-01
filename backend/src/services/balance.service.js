import { Account } from '../models/Account.js';
import { Transaction } from '../models/Transaction.js';
import { ApiError } from '../utils/ApiError.js';

/** Recompute an account balance from its initial balance + all transactions. */
export async function recomputeAccountBalance(accountId) {
  const account = await Account.findById(accountId);
  if (!account) throw ApiError.notFound('Account not found');

  const [agg] = await Transaction.aggregate([
    { $match: { $or: [{ account: account._id }, { toAccount: account._id }] } },
    {
      $group: {
        _id: null,
        inflow: {
          $sum: {
            $cond: [
              { $or: [
                { $and: [{ $eq: ['$type', 'income'] }, { $eq: ['$account', account._id] }] },
                { $and: [{ $eq: ['$type', 'transfer'] }, { $eq: ['$toAccount', account._id] }] },
              ] },
              '$amount',
              0,
            ],
          },
        },
        outflow: {
          $sum: {
            $cond: [
              { $or: [
                { $and: [{ $eq: ['$type', 'expense'] }, { $eq: ['$account', account._id] }] },
                { $and: [{ $eq: ['$type', 'transfer'] }, { $eq: ['$account', account._id] }] },
              ] },
              '$amount',
              0,
            ],
          },
        },
      },
    },
  ]);

  const inflow = agg?.inflow || 0;
  const outflow = agg?.outflow || 0;
  account.currentBalance = account.initialBalance + inflow - outflow;
  await account.save();
  return account;
}

export async function recomputeAccounts(accountIds = []) {
  const unique = [...new Set(accountIds.filter(Boolean).map(String))];
  return Promise.all(unique.map((id) => recomputeAccountBalance(id)));
}

export async function getTotalBalance(userId) {
  const [agg] = await Account.aggregate([
    { $match: { user: userId, isArchived: false } },
    { $group: { _id: null, total: { $sum: '$currentBalance' } } },
  ]);
  return agg?.total || 0;
}
