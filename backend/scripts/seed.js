/**
 * Seeds a demo user matching the mockup data (Ali Hassan, PKR accounts).
 * Usage: npm run seed
 */
import mongoose from 'mongoose';
import { env } from '../src/config/env.js';
import { connectDB } from '../src/config/db.js';
import { User } from '../src/models/User.js';
import { Account } from '../src/models/Account.js';
import { Category } from '../src/models/Category.js';
import { DEFAULT_CATEGORIES } from '../src/utils/defaults.js';

const DEMO_EMAIL = 'ali.hassan@example.com';
const DEMO_PASSWORD = 'hisab12345';

async function seed() {
  await connectDB();

  await User.deleteOne({ email: DEMO_EMAIL });

  const user = await User.create({
    fullName: 'Ali Hassan',
    email: DEMO_EMAIL,
    phone: '+92 300 1234567',
    password: DEMO_PASSWORD,
    isVerified: true,
    onboardingStage: 'done',
  });

  await Category.deleteMany({ user: user._id });
  await Category.insertMany(
    DEFAULT_CATEGORIES.map((c) => ({ ...c, user: user._id, isDefault: true }))
  );

  await Account.deleteMany({ user: user._id });
  const accounts = [
    { name: 'Cash in Hand', type: 'cash', balance: 45000, icon: 'payments', isDefault: true },
    { name: 'Bank Account', type: 'bank', balance: 75000, icon: 'account_balance' },
    { name: 'JazzCash', type: 'wallet', balance: 5000, icon: 'account_balance_wallet' },
    { name: 'Easypaisa', type: 'wallet', balance: 2500, icon: 'account_balance_wallet' },
  ];
  await Account.insertMany(
    accounts.map((a) => ({
      user: user._id,
      name: a.name,
      type: a.type,
      icon: a.icon,
      currency: 'PKR',
      initialBalance: a.balance,
      currentBalance: a.balance,
      isDefault: !!a.isDefault,
    }))
  );

  console.log('\n  Demo account seeded');
  console.log(`  email:    ${DEMO_EMAIL}`);
  console.log(`  password: ${DEMO_PASSWORD}`);
  console.log(`  ${accounts.length} accounts, ${DEFAULT_CATEGORIES.length} categories\n`);

  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error('[seed] failed', err);
  process.exit(1);
});
