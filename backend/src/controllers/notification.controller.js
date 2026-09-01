import { z } from 'zod';
import { Notification } from '../models/Notification.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, paginated } from '../utils/respond.js';

export const listQuerySchema = z.object({
  isRead: z.enum(['true', 'false']).optional(),
  type: z.enum(['expense', 'income', 'debt_reminder', 'backup', 'report', 'system']).optional(),
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(30),
});

/** GET /notifications */
export const list = catchAsync(async (req, res) => {
  const { page, limit, isRead, type } = req.query;
  const filter = {
    user: req.user._id,
    ...(isRead !== undefined ? { isRead: isRead === 'true' } : {}),
    ...(type ? { type } : {}),
  };

  const [items, total, unreadCount] = await Promise.all([
    Notification.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
    Notification.countDocuments(filter),
    Notification.countDocuments({ user: req.user._id, isRead: false }),
  ]);

  res.set('X-Unread-Count', String(unreadCount));
  return paginated(res, items, { page, limit, total });
});

/** GET /notifications/unread-count */
export const unreadCount = catchAsync(async (req, res) =>
  ok(res, { count: await Notification.countDocuments({ user: req.user._id, isRead: false }) })
);

/** PATCH /notifications/:id/read */
export const markRead = catchAsync(async (req, res) => {
  const notification = await Notification.findOneAndUpdate(
    { _id: req.params.id, user: req.user._id },
    { $set: { isRead: true } },
    { new: true }
  );
  if (!notification) throw ApiError.notFound('Notification not found');
  return ok(res, { notification }, 'Marked as read');
});

/** PATCH /notifications/read-all */
export const markAllRead = catchAsync(async (req, res) => {
  const result = await Notification.updateMany(
    { user: req.user._id, isRead: false },
    { $set: { isRead: true } }
  );
  return ok(res, { updated: result.modifiedCount }, 'All marked as read');
});

/** DELETE /notifications/:id */
export const remove = catchAsync(async (req, res) => {
  const deleted = await Notification.findOneAndDelete({
    _id: req.params.id,
    user: req.user._id,
  });
  if (!deleted) throw ApiError.notFound('Notification not found');
  return ok(res, {}, 'Notification deleted');
});

/** DELETE /notifications — clear all */
export const clearAll = catchAsync(async (req, res) => {
  const result = await Notification.deleteMany({ user: req.user._id });
  return ok(res, { deleted: result.deletedCount }, 'Notifications cleared');
});
