import { Router } from 'express';
import * as c from '../controllers/transaction.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/summary', c.summary);
router.get('/', validate(c.listQuerySchema, 'query'), c.listTransactions);
router.post('/', validate(c.createTransactionSchema), c.createTransaction);
router.get('/:id', c.getTransaction);
router.patch('/:id', validate(c.updateTransactionSchema), c.updateTransaction);
router.delete('/:id', c.deleteTransaction);

export default router;
