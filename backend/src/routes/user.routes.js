import { Router } from 'express';
import * as c from '../controllers/user.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';
import { authLimiter } from '../middleware/rateLimit.js';
import { uploadAvatar } from '../middleware/upload.js';

const router = Router();
router.use(protect);

router.patch('/me', validate(c.updateProfileSchema), c.updateProfile);
router.post('/me/avatar', uploadAvatar, c.uploadAvatar);
router.patch('/me/settings', validate(c.settingsSchema), c.updateSettings);
router.post('/me/password', authLimiter, validate(c.changePasswordSchema), c.changePassword);
router.get('/me/security', c.securityStatus);
router.post('/me/pin', validate(c.pinSchema), c.setPin);
router.post('/me/pin/verify', authLimiter, c.verifyPin);
router.delete('/me/pin', c.removePin);

export default router;
