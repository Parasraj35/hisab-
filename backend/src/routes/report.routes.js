import { Router } from 'express';
import * as c from '../controllers/report.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/overview', validate(c.rangeSchema, 'query'), c.overview);
router.get('/trend', validate(c.rangeSchema, 'query'), c.trend);
router.get('/export', validate(c.exportSchema, 'query'), c.exportReport);

export default router;
