import mongoose from 'mongoose';

const transactionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, enum: ['expense', 'income', 'transfer'], required: true },
    amount: { type: Number, required: true, min: 0.01 },
    account: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
    toAccount: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'Category', default: null },
    date: { type: Date, required: true, default: Date.now },
    note: { type: String, trim: true, default: '' },
    transferGroup: { type: String, default: null },
    meta: { type: Object, default: {} },
  },
  { timestamps: true }
);

transactionSchema.index({ user: 1, date: -1 });
transactionSchema.index({ user: 1, type: 1, date: -1 });
transactionSchema.index({ user: 1, account: 1, date: -1 });

export const Transaction = mongoose.model('Transaction', transactionSchema);
