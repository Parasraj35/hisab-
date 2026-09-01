import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { User } from '../models/User.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok } from '../utils/respond.js';

export const updateProfileSchema = z.object({
  fullName: z.string().min(2).max(60).optional(),
  phone: z.string().max(20).optional(),
  avatarUrl: z.string().optional(),
});

export const settingsSchema = z.object({
  currency: z.string().length(3).optional(),
  dateFormat: z.string().max(20).optional(),
  theme: z.enum(['system', 'light', 'dark']).optional(),
  language: z.string().max(5).optional(),
  appLock: z.boolean().optional(),
  biometricUnlock: z.boolean().optional(),
  twoStepVerification: z.boolean().optional(),
  autoLockMinutes: z.coerce.number().min(0).max(60).optional(),
  notifications: z
    .object({
      transactions: z.boolean().optional(),
      debtReminders: z.boolean().optional(),
      weeklyReport: z.boolean().optional(),
    })
    .optional(),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string().min(8, 'Password must be at least 8 characters'),
});

export const pinSchema = z.object({
  pin: z.string().regex(/^\d{4,6}$/, 'PIN must be 4 to 6 digits'),
  currentPin: z.string().optional(),
});

/** PATCH /users/me */
export const updateProfile = catchAsync(async (req, res) => {
  Object.assign(req.user, req.body);
  await req.user.save();
  return ok(res, { user: req.user.toJSON() }, 'Profile updated');
});

/** PATCH /users/me/settings */
export const updateSettings = catchAsync(async (req, res) => {
  const { notifications, ...rest } = req.body;

  Object.assign(req.user.settings, rest);
  if (notifications) {
    Object.assign(req.user.settings.notifications, notifications);
  }

  // App lock is meaningless without a PIN — reject rather than silently enable.
  if (rest.appLock === true && !req.user.pinHash) {
    const withPin = await User.findById(req.user._id).select('+pinHash');
    if (!withPin.pinHash) {
      throw ApiError.badRequest('Set a PIN before turning on app lock');
    }
  }

  await req.user.save();
  return ok(res, { settings: req.user.settings }, 'Settings saved');
});

/** POST /users/me/password */
export const changePassword = catchAsync(async (req, res) => {
  const user = await User.findById(req.user._id).select('+password');
  const matches = await user.comparePassword(req.body.currentPassword);
  if (!matches) throw ApiError.badRequest('Current password is incorrect');

  if (req.body.currentPassword === req.body.newPassword) {
    throw ApiError.badRequest('New password must be different');
  }

  user.password = req.body.newPassword;
  await user.save();
  return ok(res, {}, 'Password changed');
});

/** POST /users/me/pin */
export const setPin = catchAsync(async (req, res) => {
  const user = await User.findById(req.user._id).select('+pinHash');

  // Changing an existing PIN requires proving you know the old one.
  if (user.pinHash) {
    if (!req.body.currentPin) throw ApiError.badRequest('Enter your current PIN');
    const matches = await bcrypt.compare(req.body.currentPin, user.pinHash);
    if (!matches) throw ApiError.badRequest('Current PIN is incorrect');
  }

  user.pinHash = await bcrypt.hash(req.body.pin, 10);
  await user.save();
  return ok(res, { hasPin: true }, 'PIN saved');
});

/** POST /users/me/pin/verify — unlocking the app */
export const verifyPin = catchAsync(async (req, res) => {
  const user = await User.findById(req.user._id).select('+pinHash');
  if (!user.pinHash) throw ApiError.badRequest('No PIN is set');

  const matches = await bcrypt.compare(String(req.body.pin || ''), user.pinHash);
  if (!matches) throw ApiError.unauthorized('Incorrect PIN');

  return ok(res, { verified: true }, 'PIN verified');
});

/** DELETE /users/me/pin */
export const removePin = catchAsync(async (req, res) => {
  const user = await User.findById(req.user._id).select('+pinHash');
  user.pinHash = null;
  // App lock and biometrics both depend on a PIN, so clear them together.
  user.settings.appLock = false;
  user.settings.biometricUnlock = false;
  await user.save();
  return ok(res, { hasPin: false }, 'PIN removed');
});

/** GET /users/me/security */
export const securityStatus = catchAsync(async (req, res) => {
  const user = await User.findById(req.user._id).select('+pinHash');
  return ok(res, {
    hasPin: !!user.pinHash,
    appLock: user.settings.appLock,
    biometricUnlock: user.settings.biometricUnlock,
    twoStepVerification: user.settings.twoStepVerification,
    autoLockMinutes: user.settings.autoLockMinutes,
  });
});
