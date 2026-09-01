import { z } from 'zod';
import { OAuth2Client } from 'google-auth-library';
import { User } from '../models/User.js';
import { Category } from '../models/Category.js';
import { Account } from '../models/Account.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created } from '../utils/respond.js';
import { issueTokens, verifyRefreshToken } from '../utils/tokens.js';
import { issueOtp, consumeOtp } from '../services/otp.service.js';
import { DEFAULT_CATEGORIES, defaultsForAccountType } from '../utils/defaults.js';
import { env } from '../config/env.js';

const googleClient = env.google.webClientId ? new OAuth2Client(env.google.webClientId) : null;

export const registerSchema = z.object({
  email: z.string().email('Enter a valid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  phone: z.string().min(7, 'Enter a valid phone number').optional().or(z.literal('')),
});

export const loginSchema = z.object({
  identifier: z.string().min(3, 'Enter your email or phone'),
  password: z.string().min(1, 'Password is required'),
});

export const otpSchema = z.object({ code: z.string().length(6, 'Enter the 6 digit code') });

export const googleAuthSchema = z.object({
  idToken: z.string().min(10, 'A Google ID token is required'),
});

export const profileSchema = z.object({
  fullName: z.string().min(2, 'Enter your full name'),
  email: z.string().email().optional(),
  phone: z.string().min(7).optional().or(z.literal('')),
  avatarUrl: z.string().optional(),
});

export const setupAccountSchema = z.object({
  name: z.string().min(1, 'Account name is required'),
  currency: z.string().default('PKR'),
  initialBalance: z.coerce.number().min(0).default(0),
  type: z.enum(['cash', 'bank', 'wallet', 'card', 'other']).default('cash'),
});

async function seedDefaultCategories(userId) {
  await Category.insertMany(
    DEFAULT_CATEGORIES.map((c) => ({ ...c, user: userId, isDefault: true })),
    { ordered: false }
  ).catch(() => {});
}

/** POST /api/v1/auth/register */
export const register = catchAsync(async (req, res) => {
  const { email, password, phone } = req.body;

  const existing = await User.findOne({ email });
  if (existing) throw ApiError.conflict('An account with this email already exists');

  const user = await User.create({ email, password, phone: phone || '' });
  await seedDefaultCategories(user._id);

  const otp = await issueOtp(user, 'verify_account');
  const tokens = issueTokens(user);

  return created(res, { user, tokens, otp }, 'Account created. Verify the code we sent you.');
});

/** POST /api/v1/auth/login */
export const login = catchAsync(async (req, res) => {
  const { identifier, password } = req.body;

  const user = await User.findOne({
    $or: [{ email: identifier.toLowerCase() }, { phone: identifier }],
  }).select('+password');
  if (!user) throw ApiError.unauthorized('No account found for those details');

  const matches = await user.comparePassword(password);
  if (!matches) throw ApiError.unauthorized('Incorrect password');

  user.lastLoginAt = new Date();
  await user.save({ validateBeforeSave: false });

  const tokens = issueTokens(user);
  return ok(res, { user: user.toJSON(), tokens }, 'Welcome back');
});

/** POST /api/v1/auth/google — verifies a Google ID token and signs the user in,
 * creating an account on first sign-in (linking by email if one already exists). */
export const googleAuth = catchAsync(async (req, res) => {
  if (!googleClient) {
    throw ApiError.badRequest('Google sign-in is not configured on this server');
  }

  const ticket = await googleClient
    .verifyIdToken({ idToken: req.body.idToken, audience: env.google.webClientId })
    .catch(() => {
      throw ApiError.unauthorized('That Google credential could not be verified');
    });
  const payload = ticket.getPayload();
  if (!payload?.email) {
    throw ApiError.unauthorized('Google did not share an email for this account');
  }

  let user = await User.findOne({ googleId: payload.sub });
  if (!user) {
    user = await User.findOne({ email: payload.email.toLowerCase() });
  }

  let isNewUser = false;
  if (!user) {
    isNewUser = true;
    user = await User.create({
      email: payload.email.toLowerCase(),
      fullName: payload.name || '',
      avatarUrl: payload.picture || '',
      googleId: payload.sub,
      isVerified: true,
      onboardingStage: 'profile',
    });
    await seedDefaultCategories(user._id);
  } else if (!user.googleId) {
    user.googleId = payload.sub;
    user.isVerified = true;
    await user.save({ validateBeforeSave: false });
  }

  user.lastLoginAt = new Date();
  await user.save({ validateBeforeSave: false });

  const tokens = issueTokens(user);
  return ok(res, { user: user.toJSON(), tokens, isNewUser }, 'Signed in with Google');
});

/** POST /api/v1/auth/otp/resend */
export const resendOtp = catchAsync(async (req, res) => {
  const otp = await issueOtp(req.user, 'verify_account');
  return ok(res, { otp }, 'Verification code sent');
});

/** POST /api/v1/auth/otp/verify */
export const verifyOtp = catchAsync(async (req, res) => {
  await consumeOtp(req.user, req.body.code, 'verify_account');

  req.user.isVerified = true;
  if (req.user.onboardingStage === 'otp') req.user.onboardingStage = 'profile';
  await req.user.save();

  return ok(res, { user: req.user.toJSON() }, 'Account verified');
});

/** PATCH /api/v1/auth/profile-setup */
export const profileSetup = catchAsync(async (req, res) => {
  const { fullName, phone, avatarUrl, email } = req.body;
  Object.assign(req.user, {
    fullName,
    ...(phone !== undefined ? { phone } : {}),
    ...(email ? { email } : {}),
    ...(avatarUrl !== undefined ? { avatarUrl } : {}),
  });
  if (req.user.onboardingStage === 'profile') req.user.onboardingStage = 'account';
  await req.user.save();

  return ok(res, { user: req.user.toJSON() }, 'Profile saved');
});

/** POST /api/v1/auth/account-setup */
export const accountSetup = catchAsync(async (req, res) => {
  const { name, currency, initialBalance, type } = req.body;

  const hasAccounts = await Account.countDocuments({ user: req.user._id });
  const typeDefaults = defaultsForAccountType(type);

  const account = await Account.create({
    user: req.user._id,
    name,
    type,
    currency,
    initialBalance,
    currentBalance: initialBalance,
    isDefault: hasAccounts === 0,
    icon: typeDefaults.icon,
    color: typeDefaults.color,
  });

  req.user.settings.currency = currency;
  req.user.onboardingStage = 'done';
  await req.user.save();

  return created(res, { account, user: req.user.toJSON() }, 'Account ready');
});

/** POST /api/v1/auth/refresh */
export const refresh = catchAsync(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) throw ApiError.badRequest('Refresh token is required');

  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw ApiError.unauthorized('Refresh token is invalid or expired');
  }

  const user = await User.findById(payload.sub);
  if (!user) throw ApiError.unauthorized('Account no longer exists');

  return ok(res, { tokens: issueTokens(user) }, 'Token refreshed');
});

/** GET /api/v1/auth/me */
export const me = catchAsync(async (req, res) => ok(res, { user: req.user.toJSON() }));

/** POST /api/v1/auth/forgot-password */
export const forgotPassword = catchAsync(async (req, res) => {
  const user = await User.findOne({ email: String(req.body.email || '').toLowerCase() });
  if (user) await issueOtp(user, 'reset_password');
  // Always 200 so we don't leak which emails exist.
  return ok(res, {}, 'If that account exists, a reset code has been sent');
});

/** POST /api/v1/auth/reset-password */
export const resetPassword = catchAsync(async (req, res) => {
  const { email, code, password } = req.body;
  const user = await User.findOne({ email: String(email || '').toLowerCase() }).select('+password');
  if (!user) throw ApiError.badRequest('Invalid reset request');

  await consumeOtp(user, code, 'reset_password');
  user.password = password;
  await user.save();

  return ok(res, {}, 'Password updated. You can log in now.');
});
