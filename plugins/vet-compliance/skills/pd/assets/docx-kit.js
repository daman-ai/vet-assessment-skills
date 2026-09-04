const d = require('docx');
const {
  Paragraph, TextRun, Table, TableRow, TableCell, WidthType, AlignmentType,
  BorderStyle, ShadingType, HeadingLevel, PageBreak, Footer, Header, PageNumber
} = d;

const C = {
  ink:    '33404F',   // charcoal — headings
  body:   '222B36',   // body text
  accent: '1F6F8B',   // slate blue — accents
  muted:  '6B7785',   // captions
  fill:   'EEF2F5',   // light panel
  fillA:  'E3EDF1',   // accent panel
  rule:   'C6D0D8',
  green:  '2E7D4F',
  amber:  'B26B00',
  red:    'B3372B',
};

const FONT = 'Calibri';
const USABLE = 9360; // A4 portrait, 2.54cm margins, in DXA

function txt(text, o = {}) {
  return new TextRun({
    text,
    font: FONT,
    size: o.size || 21,
    bold: !!o.bold,
    italics: !!o.italics,
    color: o.color || C.body,
  });
}

function p(text, o = {}) {
  const runs = Array.isArray(text) ? text : [txt(text, o)];
  return new Paragraph({
    children: runs,
    spacing: { before: o.before === undefined ? 0 : o.before, after: o.after === undefined ? 120 : o.after, line: o.line || 264 },
    alignment: o.align,
    indent: o.indent,
    keepNext: !!o.keepNext,
    pageBreakBefore: !!o.pageBreak,
    border: o.border,
  });
}

function h1(text, o = {}) {
  return new Paragraph({
    children: [new TextRun({ text, font: FONT, size: 34, bold: true, color: C.ink })],
    spacing: { before: o.before === undefined ? 0 : o.before, after: 200 },
    pageBreakBefore: !!o.pageBreak,
    keepNext: true,
  });
}

function h2(text, o = {}) {
  return new Paragraph({
    children: [new TextRun({ text, font: FONT, size: 25, bold: true, color: C.accent })],
    spacing: { before: o.before === undefined ? 260 : o.before, after: 110 },
    pageBreakBefore: !!o.pageBreak,
    keepNext: true,
  });
}

function h3(text, o = {}) {
  return new Paragraph({
    children: [new TextRun({ text, font: FONT, size: 21, bold: true, color: C.ink })],
    spacing: { before: o.before === undefined ? 180 : o.before, after: 70 },
    keepNext: true,
  });
}

function bullet(text, o = {}) {
  const runs = Array.isArray(text) ? text : [txt(text, o)];
  return new Paragraph({
    children: runs,
    numbering: { reference: o.ref || (o.numbered ? 'numlist' : 'bullets'), level: o.level || 0 },
    spacing: { before: 20, after: o.after === undefined ? 60 : o.after, line: 264 },
    keepNext: !!o.keepNext,
  });
}

const noBorder = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const thin = (color) => ({ style: BorderStyle.SINGLE, size: 4, color: color || C.rule });

function cell(children, o = {}) {
  const kids = (Array.isArray(children) ? children : [children]).map(c =>
    typeof c === 'string' ? p(c, { after: 40, size: o.size || 20, bold: o.bold, color: o.color }) : c
  );
  return new TableCell({
    children: kids,
    width: { size: o.w, type: WidthType.DXA },
    shading: o.fill ? { type: ShadingType.CLEAR, fill: o.fill, color: 'auto' } : undefined,
    margins: { top: 70, bottom: 70, left: 110, right: 110 },
    columnSpan: o.span,
    verticalAlign: d.VerticalAlign.TOP,
  });
}

function table(widths, rows, o = {}) {
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths: widths,
    rows,
    borders: {
      top: thin(), bottom: thin(), left: thin(), right: thin(),
      insideHorizontal: thin(), insideVertical: thin(),
    },
    ...o,
  });
}

function headRow(widths, labels) {
  return new TableRow({
    tableHeader: true,
    children: labels.map((l, i) =>
      cell([p(l, { bold: true, color: 'FFFFFF', size: 20, after: 20 })], { w: widths[i], fill: C.ink })
    ),
  });
}

function row(widths, cells, o = {}) {
  return new TableRow({
    cantSplit: !!o.cantSplit,
    children: cells.map((c, i) =>
      cell(c, { w: widths[i], fill: o.fill, bold: o.bold, size: o.size })
    ),
  });
}

// Grey callout panel spanning the page
function panel(title, lines, fill) {
  const kids = [p(title, { bold: true, color: C.ink, size: 20, after: 60 })];
  lines.forEach(l => kids.push(p(l, { size: 20, after: 50 })));
  return new Table({
    width: { size: USABLE, type: WidthType.DXA },
    columnWidths: [USABLE],
    rows: [new TableRow({
      children: [new TableCell({
        children: kids,
        width: { size: USABLE, type: WidthType.DXA },
        shading: { type: ShadingType.CLEAR, fill: fill || C.fill, color: 'auto' },
        margins: { top: 130, bottom: 130, left: 160, right: 160 },
        borders: { top: noBorder, bottom: noBorder, left: noBorder, right: noBorder },
      })],
    })],
    borders: {
      top: noBorder, bottom: noBorder, left: noBorder, right: noBorder,
      insideHorizontal: noBorder, insideVertical: noBorder,
    },
  });
}

const numbering = {
  config: [
    {
      reference: 'bullets',
      levels: [
        { level: 0, format: d.LevelFormat.BULLET, text: '\u2022', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 340, hanging: 220 } }, run: { color: C.accent, font: FONT } } },
        { level: 1, format: d.LevelFormat.BULLET, text: '\u2013', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 680, hanging: 220 } }, run: { color: C.accent, font: FONT } } },
      ],
    },
    {
      reference: 'numlist',
      levels: [
        { level: 0, format: d.LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 360, hanging: 240 } }, run: { color: C.accent, font: FONT, bold: true } } },
      ],
    },
    {
      reference: 'numlist2',
      levels: [
        { level: 0, format: d.LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 360, hanging: 240 } }, run: { color: C.accent, font: FONT, bold: true } } },
      ],
    },
    {
      reference: 'numlist3',
      levels: [
        { level: 0, format: d.LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 360, hanging: 240 } }, run: { color: C.accent, font: FONT, bold: true } } },
      ],
    },
  ],
};

function docFooter(label) {
  return new Footer({
    children: [
      new Paragraph({
        children: [
          new TextRun({ text: label + '   |   Page ', font: FONT, size: 16, color: C.muted }),
          new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 16, color: C.muted }),
          new TextRun({ text: ' of ', font: FONT, size: 16, color: C.muted }),
          new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FONT, size: 16, color: C.muted }),
        ],
        alignment: AlignmentType.RIGHT,
        border: { top: { style: BorderStyle.SINGLE, size: 4, color: C.rule, space: 6 } },
      }),
    ],
  });
}

const sectionProps = {
  page: {
    margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 },
  },
};

module.exports = {
  d, C, FONT, USABLE, txt, p, h1, h2, h3, bullet, cell, table, headRow, row,
  panel, numbering, docFooter, sectionProps, noBorder, thin,
};
