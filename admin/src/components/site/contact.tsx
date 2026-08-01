'use client';

import { useState } from 'react';

/**
 * Contact and hire. Posts to /api/contact, which relays over the studio's own
 * SMTP. When the route reports it is not configured (503), the form degrades to
 * a mailto link built from NEXT_PUBLIC_CONTACT_EMAIL, so the section works on
 * day one and gets better when the secrets land.
 */

type Status = 'idle' | 'sending' | 'sent' | 'failed' | 'unconfigured';

const CONTACT_EMAIL = process.env.NEXT_PUBLIC_CONTACT_EMAIL ?? 'info@mindberzerk.com';

const inputCls =
  'w-full rounded-xl border-[1.5px] border-site-line bg-site-card px-3.5 py-2.5 text-[14px] text-site-ink placeholder:text-site-ink-3 focus:border-site-accent focus:outline-none';

export function Contact() {
  const [status, setStatus] = useState<Status>('idle');
  const [error, setError] = useState('');

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const data = new FormData(form);
    const body = {
      name: String(data.get('name') ?? ''),
      email: String(data.get('email') ?? ''),
      kind: String(data.get('kind') ?? 'general'),
      message: String(data.get('message') ?? ''),
      // The honeypot. Humans never see it; bots fill it and get a polite 200.
      company: String(data.get('company') ?? ''),
    };
    setStatus('sending');
    setError('');
    try {
      const res = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (res.status === 503) {
        setStatus('unconfigured');
        return;
      }
      if (!res.ok) {
        const payload = (await res.json().catch(() => null)) as { error?: string } | null;
        setError(payload?.error ?? 'The message could not be sent.');
        setStatus('failed');
        return;
      }
      form.reset();
      setStatus('sent');
    } catch {
      setError('The message could not be sent.');
      setStatus('failed');
    }
  }

  return (
    <div className="grid overflow-hidden rounded-[28px] border border-site-line bg-site-card shadow-site-soft lg:grid-cols-[0.9fr_1.1fr]">
      <div
        className="flex flex-col justify-center p-8 sm:p-12"
        style={{
          background:
            'radial-gradient(560px 340px at 0% 0%, var(--color-site-lav) 0%, transparent 65%), radial-gradient(480px 320px at 100% 100%, var(--color-site-peach) 0%, transparent 62%), var(--color-site-card)',
        }}
      >
        <h2 className="text-[clamp(28px,3vw,36px)] font-bold">Work with the studio.</h2>
        <p className="mt-3.5 max-w-[42ch] text-base leading-relaxed">
          Commission an app, propose a collaboration, or ask about anything we ship. Messages land
          directly in the studio inbox and get a reply from the person who builds the apps.
        </p>
        <a href={`mailto:${CONTACT_EMAIL}`} className="mt-5 inline-flex items-center gap-2 text-[15px] font-bold text-site-accent transition hover:text-site-accent-deep">
          {CONTACT_EMAIL}
        </a>
      </div>

      <form onSubmit={submit} className="flex flex-col gap-3.5 p-8 sm:p-12">
        <div className="grid gap-3.5 sm:grid-cols-2">
          <label className="block">
            <span className="mb-1.5 block text-[13px] font-semibold text-site-ink">Name</span>
            <input name="name" required maxLength={120} autoComplete="name" className={inputCls} />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-[13px] font-semibold text-site-ink">Email</span>
            <input name="email" type="email" required maxLength={200} autoComplete="email" className={inputCls} />
          </label>
        </div>
        <label className="block">
          <span className="mb-1.5 block text-[13px] font-semibold text-site-ink">What is this about</span>
          <select name="kind" className={inputCls} defaultValue="general">
            <option value="general">A question or some feedback</option>
            <option value="hire">Hire the studio</option>
            <option value="support">Support for an app</option>
          </select>
        </label>
        <label className="block">
          <span className="mb-1.5 block text-[13px] font-semibold text-site-ink">Message</span>
          <textarea name="message" required maxLength={5000} rows={5} className={inputCls} />
        </label>
        {/* Honeypot: visually gone, present in the DOM, tempting to a bot. */}
        <label className="absolute -left-[9999px] top-auto" aria-hidden tabIndex={-1}>
          Company
          <input name="company" tabIndex={-1} autoComplete="off" />
        </label>

        <div className="mt-1 flex flex-wrap items-center gap-4">
          <button
            type="submit"
            disabled={status === 'sending'}
            className="rounded-full bg-site-accent px-6 py-3 text-[15px] font-semibold text-white shadow-[0_12px_28px_rgba(109,74,232,0.32)] transition hover:-translate-y-px hover:bg-site-accent-deep disabled:opacity-60 disabled:hover:translate-y-0"
          >
            {status === 'sending' ? 'Sending' : 'Send message'}
          </button>
          {status === 'sent' && <span className="text-[13.5px] font-semibold text-site-ok">Sent. We will get back to you.</span>}
          {status === 'failed' && <span className="text-[13.5px] font-semibold text-site-plan">{error}</span>}
          {status === 'unconfigured' && (
            <span className="text-[13.5px] font-medium text-site-ink-3">
              The form is not wired up yet. Email us at{' '}
              <a className="font-bold text-site-accent" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
            </span>
          )}
        </div>
      </form>
    </div>
  );
}
