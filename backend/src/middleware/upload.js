import fs from 'fs';
import multer from 'multer';
import path from 'path';
import { ApiError } from '../utils/ApiError.js';

const avatarsDir = path.join(process.cwd(), 'uploads', 'avatars');
fs.mkdirSync(avatarsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, avatarsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${req.user._id}-${Date.now()}${ext}`);
  },
});

const allowedTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

const avatarUpload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!allowedTypes.has(file.mimetype)) {
      cb(new Error('Only JPEG, PNG or WEBP images are allowed'));
      return;
    }
    cb(null, true);
  },
}).single('avatar');

/** Wraps multer so its callback-style errors become ApiErrors (400, not 500). */
export const uploadAvatar = (req, res, next) => {
  avatarUpload(req, res, (err) => {
    if (err) return next(ApiError.badRequest(err.message));
    next();
  });
};
