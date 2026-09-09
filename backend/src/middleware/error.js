import mongoose from 'mongoose';
import * as Sentry from '@sentry/node';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';

export const notFoundHandler = (req, _res, next) =>
  next(ApiError.notFound(`Route ${req.method} ${req.originalUrl} not found`));

export const errorHandler = (err, _req, res, _next) => {
  let error = err;

  if (error instanceof mongoose.Error.CastError) {
    error = ApiError.badRequest(`Invalid value for "${error.path}"`);
  }
  if (error?.code === 11000) {
    const field = Object.keys(error.keyValue || {}).join(', ');
    error = ApiError.conflict(`Duplicate value for ${field}`);
  }
  if (error instanceof mongoose.Error.ValidationError) {
    error = ApiError.badRequest(
      'Validation failed',
      Object.values(error.errors).map((e) => ({ field: e.path, message: e.message }))
    );
  }
  if (!(error instanceof ApiError)) {
    error = new ApiError(error.statusCode || 500, error.message || 'Internal server error');
  }

  if (env.nodeEnv !== 'test' && error.statusCode >= 500) {
    console.error(err);
    Sentry.captureException(err);
  }

  res.status(error.statusCode).json({
    success: false,
    message: error.message,
    ...(error.details ? { errors: error.details } : {}),
    ...(env.nodeEnv === 'development' && error.statusCode >= 500 ? { stack: err.stack } : {}),
  });
};
