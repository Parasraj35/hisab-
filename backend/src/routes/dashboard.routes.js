import { Router } from 'express';
import * as c from '../controllers/dashboard.controller.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);
router.get('/overview', c.overview);

export default router;
