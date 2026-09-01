import { Router } from 'express';
import * as c from '../controllers/debt.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/', c.listDebts);
router.post('/', validate(c.createDebtSchema), c.createDebt);
router.get('/:id', c.getDebt);
router.patch('/:id', validate(c.updateDebtSchema), c.updateDebt);
router.delete('/:id', c.deleteDebt);
router.post('/:id/settle', validate(c.settlementSchema), c.settleDebt);
router.delete('/:id/settle/:settlementId', c.removeSettlement);

export default router;
