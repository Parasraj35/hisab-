import { randomInt } from 'crypto';
import { Otp } from '../models/Otp.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';

// crypto.randomInt, not Math.random — OTP codes are a security boundary.
const generateCode = () => String(randomInt(100000, 1000000));

export async function issueOtp(user, purpose = 'verify_account') {
  await Otp.updateMany(
    { user: user._id, purpose, consumedAt: null },
    { $set: { consumedAt: new Date() } }
  );

  const code = generateCode();
  const codeHash = await Otp.hashCode(code);
  await Otp.create({
    user: user._id,
    codeHash,
    purpose,
    expiresAt: new Date(Date.now() + env.otp.ttlSeconds * 1000),
  });

  // Wire a real SMS/email provider here (Twilio, SendGrid, etc.). Until then
  // this logs the code for local dev only — never in production, where a
  // plaintext OTP in logs would defeat the whole point of the code.
  if (env.nodeEnv !== 'production') {
    console.log(`[otp] ${purpose} code for ${user.email}: ${code}`);
  }

  return { expiresIn: env.otp.ttlSeconds, ...(env.otp.devEcho ? { devCode: code } : {}) };
}

export async function consumeOtp(user, code, purpose = 'verify_account') {
  const otp = await Otp.findOne({ user: user._id, purpose, consumedAt: null }).sort('-createdAt');
  if (!otp) throw ApiError.badRequest('No active code. Please request a new one.');
  if (otp.expiresAt < new Date()) throw ApiError.badRequest('Code expired. Please resend.');
  if (otp.attempts >= 5) throw ApiError.tooMany('Too many wrong attempts. Request a new code.');

  const valid = await otp.verifyCode(code);
  if (!valid) {
    otp.attempts += 1;
    await otp.save();
    throw ApiError.badRequest('Incorrect verification code');
  }

  otp.consumedAt = new Date();
  await otp.save();
  return true;
}
