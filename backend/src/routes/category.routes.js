import { Router } from 'express';
import * as c from '../controllers/category.controller.js';
import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';

const router = Router();
router.use(protect);

router.get('/', c.listCategories);
router.post('/', validate(c.categorySchema), c.createCategory);
router.patch('/:id', validate(c.updateCategorySchema), c.updateCategory);
router.delete('/:id', c.deleteCategory);

export default router;
