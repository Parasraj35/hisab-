import { Router } from 'express';
import * as c from '../controllers/auth.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';
import { authLimiter, otpLimiter } from '../middleware/rateLimit.js';

const router = Router();

router.post('/register', authLimiter, validate(c.registerSchema), c.register);
router.post('/login', authLimiter, validate(c.loginSchema), c.login);
router.post('/refresh', c.refresh);
router.post('/forgot-password', otpLimiter, c.forgotPassword);
router.post('/reset-password', authLimiter, c.resetPassword);

router.use(protect);
router.get('/me', c.me);
router.patch('/profile-setup', validate(c.profileSchema), c.profileSetup);
router.post('/account-setup', validate(c.setupAccountSchema), c.accountSetup);

export default router;
