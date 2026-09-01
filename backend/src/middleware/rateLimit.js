import rateLimit from 'express-rate-limit';

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { success: false, message: 'Too many attempts. Please try again later.' },
});

export const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 6,
  message: { success: false, message: 'Too many OTP requests. Please wait a few minutes.' },
});

export const apiLimiter = rateLimit({ windowMs: 60 * 1000, limit: 200 });
