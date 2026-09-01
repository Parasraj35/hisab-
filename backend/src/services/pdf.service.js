import PDFDocument from 'pdfkit';
import dayjs from 'dayjs';

// Brand palette, kept in sync with the app's design tokens.
const FOREST = '#00563B';
const ACCENT = '#4CAF8A';
const EXPENSE = '#DC2626';
const INCOME = '#16A34A';
const MUTED = '#6B7280';
const BORDER = '#E5E7EB';

const money = (value, currency) =>
  `${currency} ${Number(value).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

/**
 * Streams a HISAB report PDF to `res`.
 * Streaming rather than buffering keeps memory flat on large date ranges.
 */
export function streamReportPdf(res, data, { detailed = true } = {}) {
  const { currency, range, income, expense, net, byCategory, transactions, user } = data;

  const doc = new PDFDocument({ size: 'A4', margin: 44, bufferPages: true });
  doc.pipe(res);

  const pageWidth = doc.page.width - 88;

  // ---- Header band
  doc.rect(0, 0, doc.page.width, 96).fill(FOREST);
  doc.fillColor('#FFFFFF').fontSize(22).font('Helvetica-Bold').text('HISAB', 44, 30);
  doc.fontSize(9).font('Helvetica').fillColor('#D7E6DF')
    .text('Manage Money. Make Better Decisions.', 44, 58);
  doc.fontSize(9).fillColor('#FFFFFF').text(
    `${dayjs(range.from).format('MMM D, YYYY')} — ${dayjs(range.to).format('MMM D, YYYY')}`,
    44, 30, { width: pageWidth, align: 'right' }
  );
  doc.fontSize(8).fillColor('#D7E6DF').text(
    user?.fullName || user?.email || '', 44, 46, { width: pageWidth, align: 'right' }
  );

  doc.y = 124;

  // ---- Summary row
  const cardWidth = (pageWidth - 20) / 3;
  const summary = [
    ['Income', income, INCOME],
    ['Expense', expense, EXPENSE],
    ['Net', net, net >= 0 ? INCOME : EXPENSE],
  ];

  // doc.y advances on every text() call, so pin the row's Y before drawing —
  // otherwise the three cards staircase down the page.
  const cardY = doc.y;
  summary.forEach(([label, value, color], i) => {
    const x = 44 + i * (cardWidth + 10);
    doc.roundedRect(x, cardY, cardWidth, 56, 6).lineWidth(1).stroke(BORDER);
    doc.fontSize(8).fillColor(MUTED).font('Helvetica')
      .text(label.toUpperCase(), x + 12, cardY + 12, { width: cardWidth - 24 });
    doc.fontSize(13).fillColor(color).font('Helvetica-Bold')
      .text(money(value, currency), x + 12, cardY + 30, { width: cardWidth - 24 });
  });

  doc.y = cardY + 82;

  // ---- Expense by category
  doc.fontSize(12).fillColor('#111827').font('Helvetica-Bold')
    .text('Expense by Category', 44, doc.y);
  doc.moveDown(0.6);

  if (byCategory.length === 0) {
    doc.fontSize(9).fillColor(MUTED).font('Helvetica')
      .text('No expenses recorded in this period.');
  } else {
    byCategory.forEach((row) => {
      const y = doc.y; // pinned: text() below would otherwise shift doc.y mid-row
      // Colour swatch
      doc.rect(44, y + 2, 8, 8).fill(row.color || ACCENT);
      doc.fontSize(9.5).fillColor('#111827').font('Helvetica')
        .text(row.name, 60, y, { width: 190, ellipsis: true });

      // Share bar
      const barX = 258;
      const barWidth = 150;
      doc.rect(barX, y + 3, barWidth, 6).fill(BORDER);
      doc.rect(barX, y + 3, Math.max(2, barWidth * row.share), 6)
        .fill(row.color || ACCENT);

      doc.fillColor(MUTED).fontSize(8.5)
        .text(`${row.percent}%`, barX + barWidth + 8, y, { width: 30 });
      doc.fillColor('#111827').fontSize(9.5).font('Helvetica-Bold')
        .text(money(row.total, currency), 0, y, {
          width: doc.page.width - 44,
          align: 'right',
        });

      doc.y = y + 18;
    });
  }

  // ---- Transaction table
  if (detailed && transactions.length > 0) {
    doc.moveDown(1.2);
    doc.fontSize(12).fillColor('#111827').font('Helvetica-Bold')
      .text('Transactions', 44, doc.y);
    doc.moveDown(0.5);

    const cols = [
      { label: 'Date', x: 44, w: 74 },
      { label: 'Description', x: 118, w: 168 },
      { label: 'Category', x: 286, w: 96 },
      { label: 'Account', x: 382, w: 78 },
      { label: 'Amount', x: 460, w: 92, align: 'right' },
    ];

    const drawHeader = () => {
      const y = doc.y;
      doc.rect(44, y - 3, pageWidth, 18).fill('#F3F4F6');
      cols.forEach((c) => {
        doc.fontSize(8).fillColor(MUTED).font('Helvetica-Bold')
          .text(c.label.toUpperCase(), c.x, y + 2, {
            width: c.w, align: c.align || 'left',
          });
      });
      doc.y = y + 20;
    };

    drawHeader();

    transactions.forEach((t) => {
      // New page before the row would overflow, and repeat the header.
      if (doc.y > doc.page.height - 70) {
        doc.addPage();
        doc.y = 50;
        drawHeader();
      }

      const y = doc.y;
      const isIncome = t.type === 'income';
      const isTransfer = t.type === 'transfer';
      const amountColor = isTransfer ? MUTED : isIncome ? INCOME : EXPENSE;
      const sign = isTransfer ? '' : isIncome ? '+' : '-';

      const description = t.note
        || (isTransfer ? `Transfer to ${t.toAccount?.name || '—'}` : t.category?.name)
        || '—';

      doc.font('Helvetica').fontSize(8.5).fillColor('#374151');
      doc.text(dayjs(t.date).format('MMM DD, YYYY'), cols[0].x, y, { width: cols[0].w });
      doc.text(description, cols[1].x, y, { width: cols[1].w, ellipsis: true });
      doc.text(isTransfer ? 'Transfer' : (t.category?.name || '—'), cols[2].x, y,
        { width: cols[2].w, ellipsis: true });
      doc.text(t.account?.name || '—', cols[3].x, y, { width: cols[3].w, ellipsis: true });
      doc.font('Helvetica-Bold').fillColor(amountColor)
        .text(`${sign}${money(t.amount, currency)}`, cols[4].x, y,
          { width: cols[4].w, align: 'right' });

      doc.y = y + 15;
      doc.moveTo(44, doc.y - 3).lineTo(doc.page.width - 44, doc.y - 3)
        .lineWidth(0.5).stroke('#F0F1F0');
    });
  }

  // ---- Footer on every page
  const pageRange = doc.bufferedPageRange();
  for (let i = 0; i < pageRange.count; i++) {
    doc.switchToPage(pageRange.start + i);
    doc.fontSize(7.5).fillColor(MUTED).font('Helvetica').text(
      `Generated by HISAB on ${dayjs().format('MMM DD, YYYY')}   ·   Page ${i + 1} of ${pageRange.count}`,
      44,
      doc.page.height - 34,
      { width: pageWidth, align: 'center' }
    );
  }

  doc.end();
}

/** CSV alternative for the "Select Format" dropdown. */
export function buildReportCsv(data) {
  const { transactions, currency } = data;
  const escape = (value) => {
    const str = String(value ?? '');
    return /[",\n]/.test(str) ? `"${str.replace(/"/g, '""')}"` : str;
  };

  const header = ['Date', 'Type', 'Description', 'Category', 'Account', 'To Account', `Amount (${currency})`];
  const rows = transactions.map((t) => [
    dayjs(t.date).format('YYYY-MM-DD'),
    t.type,
    t.note || '',
    t.category?.name || '',
    t.account?.name || '',
    t.toAccount?.name || '',
    (t.type === 'expense' ? -t.amount : t.amount).toFixed(2),
  ]);

  return [header, ...rows].map((r) => r.map(escape).join(',')).join('\n');
}
