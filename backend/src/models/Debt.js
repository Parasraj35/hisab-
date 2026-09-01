import mongoose from 'mongoose';

const settlementSchema = new mongoose.Schema(
  { amount: Number, date: { type: Date, default: Date.now }, note: String },
  { _id: true }
);

const debtSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    direction: { type: String, enum: ['lent', 'borrowed'], required: true },
    personName: { type: String, required: true, trim: true },
    personAvatar: { type: String, default: '' },
    personPhone: { type: String, default: '' },
    amount: { type: Number, required: true, min: 0.01 },
    settledAmount: { type: Number, default: 0 },
    account: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
    dueDate: { type: Date, default: null },
    note: { type: String, default: '' },
    settlements: [settlementSchema],
    status: { type: String, enum: ['pending', 'partial', 'paid'], default: 'pending' },
  },
  { timestamps: true }
);

debtSchema.methods.recalculateStatus = function recalc() {
  this.settledAmount = this.settlements.reduce((s, x) => s + x.amount, 0);
  if (this.settledAmount <= 0) this.status = 'pending';
  else if (this.settledAmount >= this.amount) this.status = 'paid';
  else this.status = 'partial';
};

export const Debt = mongoose.model('Debt', debtSchema);
