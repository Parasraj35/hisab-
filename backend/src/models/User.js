import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const settingsSchema = new mongoose.Schema(
  {
    currency: { type: String, default: 'PKR' },
    theme: { type: String, enum: ['system', 'light', 'dark'], default: 'system' },
    language: { type: String, default: 'en' },
    appLock: { type: Boolean, default: false },
    biometricUnlock: { type: Boolean, default: false },
    twoStepVerification: { type: Boolean, default: false },
    autoLockMinutes: { type: Number, default: 1 },
    notifications: {
      transactions: { type: Boolean, default: true },
      debtReminders: { type: Boolean, default: true },
      weeklyReport: { type: Boolean, default: true },
    },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    fullName: { type: String, trim: true, default: '' },
    // No `default: ''` — sparse only excludes truly-absent values from the
    // unique index, so an empty-string default would collide across every
    // phone-only signup the moment a second one landed.
    email: { type: String, lowercase: true, trim: true, unique: true, sparse: true },
    phone: { type: String, trim: true, required: true, unique: true, sparse: true },
    password: { type: String, required: true, select: false, minlength: 8 },
    avatarUrl: { type: String, default: '' },
    pinHash: { type: String, select: false, default: null },
    isVerified: { type: Boolean, default: true },
    onboardingStage: {
      type: String,
      enum: ['profile', 'account', 'done'],
      default: 'profile',
    },
    settings: { type: settingsSchema, default: () => ({}) },
    lastLoginAt: { type: Date },
  },
  { timestamps: true }
);

userSchema.pre('save', async function hashPassword(next) {
  if (!this.password || !this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

userSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

userSchema.set('toJSON', {
  transform: (_doc, ret) => {
    delete ret.password;
    delete ret.pinHash;
    delete ret.__v;
    return ret;
  },
});

export const User = mongoose.model('User', userSchema);
