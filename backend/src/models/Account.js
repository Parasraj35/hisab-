import mongoose from 'mongoose';

const accountSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, required: true, trim: true },
    type: {
      type: String,
      enum: ['cash', 'bank', 'wallet', 'card', 'other'],
      default: 'cash',
    },
    icon: { type: String, default: 'wallet' },
    color: { type: String, default: '#16A34A' },
    currency: { type: String, default: 'PKR' },
    initialBalance: { type: Number, default: 0 },
    currentBalance: { type: Number, default: 0 },
    isDefault: { type: Boolean, default: false },
    isArchived: { type: Boolean, default: false },
  },
  { timestamps: true }
);

accountSchema.index({ user: 1, name: 1 }, { unique: true });

export const Account = mongoose.model('Account', accountSchema);
