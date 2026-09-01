import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const otpSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    codeHash: { type: String, required: true },
    purpose: {
      type: String,
      enum: ['verify_account', 'reset_password', 'two_step'],
      default: 'verify_account',
    },
    attempts: { type: Number, default: 0 },
    consumedAt: { type: Date, default: null },
    expiresAt: { type: Date, required: true },
  },
  { timestamps: true }
);

otpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

otpSchema.statics.hashCode = (code) => bcrypt.hash(code, 8);
otpSchema.methods.verifyCode = function verifyCode(code) {
  return bcrypt.compare(code, this.codeHash);
};

export const Otp = mongoose.model('Otp', otpSchema);
