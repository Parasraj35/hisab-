import { Router } from 'express';
import * as c from '../controllers/backup.controller.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/', c.list);
router.post('/', c.create);
router.post('/:id/restore', c.restore);
router.delete('/:id', c.remove);

export default router;
