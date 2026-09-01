import { Router } from 'express';
import * as c from '../controllers/notification.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/', validate(c.listQuerySchema, 'query'), c.list);
router.get('/unread-count', c.unreadCount);
router.patch('/read-all', c.markAllRead);
router.patch('/:id/read', c.markRead);
router.delete('/:id', c.remove);
router.delete('/', c.clearAll);

export default router;
