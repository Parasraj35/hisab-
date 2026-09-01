import { Router } from 'express';
import authRoutes from './auth.routes.js';
import accountRoutes from './account.routes.js';
import categoryRoutes from './category.routes.js';
import transactionRoutes from './transaction.routes.js';
import dashboardRoutes from './dashboard.routes.js';
import debtRoutes from './debt.routes.js';
import savingsRoutes from './savings.routes.js';
import reportRoutes from './report.routes.js';
import notificationRoutes from './notification.routes.js';
import backupRoutes from './backup.routes.js';
import userRoutes from './user.routes.js';

const router = Router();

router.get('/health', (_req, res) =>
  res.json({ success: true, message: 'HISAB API is running', ts: new Date().toISOString() })
);

router.use('/auth', authRoutes);
router.use('/accounts', accountRoutes);
router.use('/categories', categoryRoutes);
router.use('/transactions', transactionRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/debts', debtRoutes);
router.use('/savings', savingsRoutes);
router.use('/reports', reportRoutes);
router.use('/notifications', notificationRoutes);
router.use('/backups', backupRoutes);
router.use('/users', userRoutes);


export default router;
