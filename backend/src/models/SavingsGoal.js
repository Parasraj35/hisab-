import mongoose from 'mongoose';

const contributionSchema = new mongoose.Schema(
  { amount: Number, date: { type: Date, default: Date.now }, note: String },
  { _id: true }
);

const savingsGoalSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, required: true, trim: true },
    targetAmount: { type: Number, required: true, min: 1 },
    savedAmount: { type: Number, default: 0 },
    deadline: { type: Date, default: null },
    icon: { type: String, default: 'target' },
    color: { type: String, default: '#16A34A' },
    contributions: [contributionSchema],
    isCompleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

savingsGoalSchema.virtual('progress').get(function progress() {
  return this.targetAmount ? Math.min(this.savedAmount / this.targetAmount, 1) : 0;
});

savingsGoalSchema.set('toJSON', { virtuals: true });

export const SavingsGoal = mongoose.model('SavingsGoal', savingsGoalSchema);
