import mongoose from 'mongoose';

const backupSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    sizeBytes: { type: Number, default: 0 },
    counts: { type: Object, default: {} },
    payload: { type: Object, required: true, select: false },
  },
  { timestamps: true }
);

export const Backup = mongoose.model('Backup', backupSchema);
