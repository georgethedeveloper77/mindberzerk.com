// Adapter so the builder server actions have one stable gate import. Your real
// server-side gate lives in lib/auth.ts; if its export is named `requireAdmin`,
// this file needs no change. If it is named differently (assertAdmin, etc.),
// rename here in ONE place rather than across four action files.
export { requireAdmin } from '@/lib/auth';
