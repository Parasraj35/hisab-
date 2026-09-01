import { z } from 'zod';
import { Category } from '../models/Category.js';
import { Transaction } from '../models/Transaction.js';
import { ApiError } from '../utils/ApiError.js';
import { catchAsync } from '../utils/catchAsync.js';
import { ok, created } from '../utils/respond.js';

export const categorySchema = z.object({
  name: z.string().min(1, 'Category name is required').max(40),
  type: z.enum(['expense', 'income']),
  icon: z.string().default('tag'),
  color: z.string().default('#16A34A'),
});

export const updateCategorySchema = categorySchema.partial();

/** GET /categories?type=expense */
export const listCategories = catchAsync(async (req, res) => {
  const { type } = req.query;
  const categories = await Category.find({
    user: req.user._id,
    isArchived: false,
    ...(type ? { type } : {}),
  }).sort({ isDefault: -1, name: 1 });

  return ok(res, { categories });
});

/** POST /categories */
export const createCategory = catchAsync(async (req, res) => {
  const exists = await Category.findOne({
    user: req.user._id,
    name: req.body.name,
    type: req.body.type,
  });
  if (exists) throw ApiError.conflict('That category already exists');

  const category = await Category.create({ ...req.body, user: req.user._id });
  return created(res, { category }, 'Category added');
});

/** PATCH /categories/:id */
export const updateCategory = catchAsync(async (req, res) => {
  const category = await Category.findOne({ _id: req.params.id, user: req.user._id });
  if (!category) throw ApiError.notFound('Category not found');

  Object.assign(category, req.body);
  await category.save();
  return ok(res, { category }, 'Category updated');
});

/** DELETE /categories/:id */
export const deleteCategory = catchAsync(async (req, res) => {
  const category = await Category.findOne({ _id: req.params.id, user: req.user._id });
  if (!category) throw ApiError.notFound('Category not found');

  const linked = await Transaction.countDocuments({
    user: req.user._id,
    category: category._id,
  });

  if (linked > 0) {
    category.isArchived = true;
    await category.save();
    return ok(res, { archived: true },
      `Category is used by ${linked} transaction(s) so it was archived`);
  }

  await category.deleteOne();
  return ok(res, { archived: false }, 'Category deleted');
});
