import { NextResponse } from 'next/server';
import nodemailer from 'nodemailer';

/**
 * Contact relay over the studio's own SMTP (Plesk). Cloud Run allows outbound
 * 465 and 587, so this is an ordinary authenticated send; only port 25 is
 * blocked, and nothing here uses it.
 *
 * ## Degrades, never breaks
 *
 * All five values come from Secret Manager. Until they exist, this returns 503
 * with `configured: false` and the form falls back to a mailto link. A missing
 * secret must not look like a user error.
 *
 * ## The soft defences
 *
 * A honeypot field (accepted silently, dropped) and a per-instance rate limit.
 * The limit is in-memory and per Cloud Run instance, which is exactly as strong
 * as a marketing site's contact form needs; anything stronger is a product.
 */
export const runtime = 'nodejs';

const WINDOW_MS = 10 * 60 * 1000;
const MAX_PER_WINDOW = 5;
const hits = new Map<string, number[]>();

function limited(ip: string): boolean {
  const now = Date.now();
  const list = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (list.length >= MAX_PER_WINDOW) {
    hits.set(ip, list);
    return true;
  }
  list.push(now);
  hits.set(ip, list);
  return false;
}

interface Payload {
  name: string;
  email: string;
  kind: string;
  message: string;
  company: string;
}

const KINDS = new Set(['general', 'hire', 'support']);
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function POST(request: Request) {
  const host = process.env.SITE_SMTP_HOST;
  const port = Number(process.env.SITE_SMTP_PORT ?? '465');
  const user = process.env.SITE_SMTP_USER;
  const pass = process.env.SITE_SMTP_PASS;
  const to = process.env.SITE_CONTACT_TO;

  if (!host || !user || !pass || !to || !Number.isFinite(port)) {
    return NextResponse.json({ configured: false }, { status: 503 });
  }

  let body: Partial<Payload>;
  try {
    body = (await request.json()) as Partial<Payload>;
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const name = String(body.name ?? '').trim();
  const email = String(body.email ?? '').trim();
  const kind = String(body.kind ?? 'general');
  const message = String(body.message ?? '').trim();
  const honeypot = String(body.company ?? '');

  // A filled honeypot gets a success so the bot moves on, and no email.
  if (honeypot) return NextResponse.json({ ok: true });

  if (!name || name.length > 120) {
    return NextResponse.json({ error: 'A name is required.' }, { status: 400 });
  }
  if (!EMAIL.test(email) || email.length > 200) {
    return NextResponse.json({ error: 'That email does not look right.' }, { status: 400 });
  }
  if (!KINDS.has(kind)) {
    return NextResponse.json({ error: 'Unknown message type.' }, { status: 400 });
  }
  if (!message || message.length > 5000) {
    return NextResponse.json({ error: 'A message is required, up to 5000 characters.' }, { status: 400 });
  }

  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  if (limited(ip)) {
    return NextResponse.json({ error: 'Too many messages. Try again in a few minutes.' }, { status: 429 });
  }

  const transport = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });

  const subjectKind = kind === 'hire' ? 'Hire' : kind === 'support' ? 'Support' : 'Contact';

  try {
    await transport.sendMail({
      // From must be the authenticated mailbox or Plesk may refuse the send;
      // the visitor's address rides in replyTo so replying just works.
      from: `"mindberzerk.com" <${user}>`,
      replyTo: `"${name.replace(/"/g, '')}" <${email}>`,
      to,
      subject: `[${subjectKind}] from ${name} via mindberzerk.com`,
      text: `Name: ${name}\nEmail: ${email}\nType: ${kind}\n\n${message}\n`,
    });
  } catch {
    // The SMTP error stays server-side; the visitor gets a sentence, not a
    // transcript of the mail server conversation.
    return NextResponse.json({ error: 'The message could not be sent. Email us directly instead.' }, { status: 502 });
  }

  return NextResponse.json({ ok: true });
}
