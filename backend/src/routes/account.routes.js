import { Router } from 'express';
import * as c from '../controllers/account.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/', c.listAccounts);
router.get('/total', c.totalBalance);
router.post('/', validate(c.createAccountSchema), c.createAccount);
router.get('/:id', c.getAccount);
router.patch('/:id', validate(c.updateAccountSchema), c.updateAccount);
router.delete('/:id', c.deleteAccount);
router.post('/:id/set-default', c.setDefaultAccount);

export default router;
