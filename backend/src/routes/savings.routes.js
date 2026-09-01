import { Router } from 'express';
import * as c from '../controllers/savings.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/', c.listGoals);
router.post('/', validate(c.createGoalSchema), c.createGoal);
router.get('/:id', c.getGoal);
router.patch('/:id', validate(c.updateGoalSchema), c.updateGoal);
router.delete('/:id', c.deleteGoal);
router.post('/:id/contribute', validate(c.contributionSchema), c.contribute);
router.post('/:id/withdraw', validate(c.contributionSchema), c.withdraw);

export default router;
