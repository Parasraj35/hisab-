import { z } from 'zod';
import { SavingsGoal } from '../models/SavingsGoal.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created } from '../utils/respond.js';
import { pushNotification } from '../services/notification.service.js';

export const createGoalSchema = z.object({
  name: z.string().min(1, 'Goal name is required').max(60),
  targetAmount: z.coerce.number().finite('Enter a valid amount').positive('Target must be greater than zero'),
  savedAmount: z.coerce.number().finite('Enter a valid amount').min(0).default(0),
  deadline: z.coerce.date().optional().nullable(),
  icon: z.string().default('target'),
  color: z.string().default('#4CAF8A'),
});

export const updateGoalSchema = createGoalSchema.partial();

export const contributionSchema = z.object({
  amount: z.coerce.number().finite('Enter a valid amount').positive('Amount must be greater than zero'),
  date: z.coerce.date().default(() => new Date()),
  note: z.string().max(200).optional().default(''),
});

/** Keeps savedAmount, isCompleted and the contribution log in agreement. */
function recalculate(goal) {
  if (goal.contributions.length > 0) {
    goal.savedAmount = goal.contributions.reduce((sum, c) => sum + c.amount, 0);
  }
  goal.isCompleted = goal.savedAmount >= goal.targetAmount;
}

/** GET /savings */
export const listGoals = catchAsync(async (req, res) => {
  const goals = await SavingsGoal.find({ user: req.user._id })
    .sort({ isCompleted: 1, deadline: 1, createdAt: -1 });

  const totalSaved = goals.reduce((sum, g) => sum + g.savedAmount, 0);
  const totalTarget = goals.reduce((sum, g) => sum + g.targetAmount, 0);

  return ok(res, {
    goals,
    currency: req.user.settings.currency,
    summary: {
      totalSaved,
      totalTarget,
      progress: totalTarget > 0 ? totalSaved / totalTarget : 0,
      activeCount: goals.filter((g) => !g.isCompleted).length,
      completedCount: goals.filter((g) => g.isCompleted).length,
    },
  });
});

/** GET /savings/:id */
export const getGoal = catchAsync(async (req, res) => {
  const goal = await SavingsGoal.findOne({ _id: req.params.id, user: req.user._id });
  if (!goal) throw ApiError.notFound('Goal not found');
  return ok(res, { goal });
});

/** POST /savings */
export const createGoal = catchAsync(async (req, res) => {
  const goal = new SavingsGoal({ ...req.body, user: req.user._id });

  // A non-zero starting amount is logged so the ledger stays complete.
  if (req.body.savedAmount > 0) {
    goal.contributions.push({ amount: req.body.savedAmount, note: 'Opening amount' });
  }
  recalculate(goal);
  await goal.save();

  return created(res, { goal }, 'Goal created');
});

/** PATCH /savings/:id */
export const updateGoal = catchAsync(async (req, res) => {
  const goal = await SavingsGoal.findOne({ _id: req.params.id, user: req.user._id });
  if (!goal) throw ApiError.notFound('Goal not found');

  // savedAmount is derived from contributions — don't let a patch override it.
  const { savedAmount, ...safe } = req.body;
  Object.assign(goal, safe);
  recalculate(goal);
  await goal.save();

  return ok(res, { goal }, 'Goal updated');
});

/** DELETE /savings/:id */
export const deleteGoal = catchAsync(async (req, res) => {
  const goal = await SavingsGoal.findOneAndDelete({
    _id: req.params.id,
    user: req.user._id,
  });
  if (!goal) throw ApiError.notFound('Goal not found');
  return ok(res, {}, 'Goal deleted');
});

/** POST /savings/:id/contribute */
export const contribute = catchAsync(async (req, res) => {
  const goal = await SavingsGoal.findOne({ _id: req.params.id, user: req.user._id });
  if (!goal) throw ApiError.notFound('Goal not found');

  const wasCompleted = goal.isCompleted;
  goal.contributions.push(req.body);
  recalculate(goal);
  await goal.save();

  if (!wasCompleted && goal.isCompleted) {
    await pushNotification(req.user._id, {
      type: 'system',
      title: 'Goal Reached',
      body: `You hit your ${goal.name} target of ${req.user.settings.currency} ${goal.targetAmount}`,
      meta: { goalId: goal._id },
    });
  }

  return ok(res, { goal }, 'Contribution added');
});

/** POST /savings/:id/withdraw — pulling money back out of a goal */
export const withdraw = catchAsync(async (req, res) => {
  const goal = await SavingsGoal.findOne({ _id: req.params.id, user: req.user._id });
  if (!goal) throw ApiError.notFound('Goal not found');

  if (req.body.amount > goal.savedAmount) {
    throw ApiError.badRequest(
      `Only ${goal.savedAmount.toFixed(2)} is saved in this goal`
    );
  }

  // Stored as a negative contribution so the log reads as a full history.
  goal.contributions.push({
    amount: -req.body.amount,
    date: req.body.date,
    note: req.body.note || 'Withdrawal',
  });
  recalculate(goal);
  await goal.save();

  return ok(res, { goal }, 'Withdrawal recorded');
});
