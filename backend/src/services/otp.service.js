import { randomInt } from 'crypto';
import { Otp } from '../models/Otp.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';
import { sendEmail } from './email.service.js';

// crypto.randomInt, not Math.random — OTP codes are a security boundary.
const generateCode = () => String(randomInt(100000, 1000000));

const SUBJECTS = {
  verify_account: 'Verify your HISAB account',
  reset_password: 'Reset your HISAB password',
  two_step: 'Your HISAB sign-in code',
};

function otpEmailHtml(code, purpose) {
  const line =
    purpose === 'reset_password'
      ? 'Use this code to reset your password:'
      : purpose === 'two_step'
        ? 'Use this code to finish signing in:'
        : 'Use this code to verify your account:';
  return `
    <div style="font-family:sans-serif;max-width:420px;margin:0 auto">
      <p>${line}</p>
      <p style="font-size:32px;font-weight:700;letter-spacing:4px;margin:16px 0">${code}</p>
      <p style="color:#6B7280;font-size:13px">This code expires in ${Math.round(env.otp.ttlSeconds / 60)} minutes. If you didn't request this, you can ignore this email.</p>
    </div>
  `;
}

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

  // Logged for local dev only — never in production, where a plaintext OTP
  // in logs would defeat the whole point of the code.
  if (env.nodeEnv !== 'production') {
    console.log(`[otp] ${purpose} code for ${user.email}: ${code}`);
  }

  const delivered = await sendEmail({
    to: user.email,
    subject: SUBJECTS[purpose] || SUBJECTS.verify_account,
    html: otpEmailHtml(code, purpose),
  });
  if (!delivered && env.nodeEnv === 'production') {
    console.error(`[otp] failed to deliver ${purpose} code to ${user.email}`);
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
