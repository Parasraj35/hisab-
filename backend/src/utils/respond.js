export const ok = (res, data, message = 'Success') =>
  res.status(200).json({ success: true, message, data });

export const created = (res, data, message = 'Created') =>
  res.status(201).json({ success: true, message, data });

export const paginated = (res, items, { page, limit, total }) =>
  res.status(200).json({
    success: true,
    message: 'Success',
    data: items,
    meta: { page, limit, total, totalPages: Math.ceil(total / limit) || 1 },
  });
