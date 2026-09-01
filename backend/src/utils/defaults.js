export const DEFAULT_CATEGORIES = [
  { name: 'Food & Dining', type: 'expense', icon: 'restaurant', color: '#F97316' },
  { name: 'Transport', type: 'expense', icon: 'directions_car', color: '#3B82F6' },
  { name: 'Utilities', type: 'expense', icon: 'bolt', color: '#EAB308' },
  { name: 'Shopping', type: 'expense', icon: 'shopping_bag', color: '#A855F7' },
  { name: 'Health', type: 'expense', icon: 'favorite', color: '#EF4444' },
  { name: 'Education', type: 'expense', icon: 'school', color: '#0EA5E9' },
  { name: 'Entertainment', type: 'expense', icon: 'movie', color: '#EC4899' },
  { name: 'Others', type: 'expense', icon: 'category', color: '#6B7280' },
  { name: 'Salary', type: 'income', icon: 'payments', color: '#16A34A' },
  { name: 'Freelance', type: 'income', icon: 'laptop', color: '#14B8A6' },
  { name: 'Business', type: 'income', icon: 'storefront', color: '#22C55E' },
  { name: 'Gift', type: 'income', icon: 'card_giftcard', color: '#F59E0B' },
  { name: 'Other Income', type: 'income', icon: 'add_circle', color: '#6B7280' },
];

// Same account-type icon logic already used ad hoc in auth.controller.js's
// accountSetup, extended with a matching color so accounts are visually
// distinguishable by type instead of every account defaulting to the same
// green (the model's `color` default).
const ACCOUNT_TYPE_DEFAULTS = {
  cash: { icon: 'payments', color: '#22A447' },
  bank: { icon: 'account_balance', color: '#3B82F6' },
  wallet: { icon: 'account_balance_wallet', color: '#8B5CF6' },
  card: { icon: 'credit_card', color: '#F59E0B' },
  other: { icon: 'wallet', color: '#6B7280' },
};

export function defaultsForAccountType(type) {
  return ACCOUNT_TYPE_DEFAULTS[type] || ACCOUNT_TYPE_DEFAULTS.other;
}
