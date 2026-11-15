// Shared helpers: API client, safe HTML, formatting, modal, toast, charts, icons.

// ---------- safe HTML ----------
// Every interpolated value is escaped unless it is already Safe (built with h`` or raw()).
class Safe { constructor(s) { this.s = s; } toString() { return this.s; } }
const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
export const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ESC[c]);
const conv = (v) => (v instanceof Safe ? v.s : Array.isArray(v) ? v.map(conv).join('') : v === false || v == null ? '' : esc(v));
export function h(strings, ...vals) {
  let out = strings[0];
  vals.forEach((v, i) => { out += conv(v) + strings[i + 1]; });
  return new Safe(out);
}
export const raw = (s) => new Safe(String(s));
export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
export function mount(el, html) { el.innerHTML = String(html); return el; }

// ---------- storage (never throws) ----------
export const store = {
  get(k) { try { return sessionStorage.getItem(k) ?? localStorage.getItem(k); } catch { return null; } },
  set(k, v, keep) {
    try { (keep ? localStorage : sessionStorage).setItem(k, v); (keep ? sessionStorage : localStorage).removeItem(k); } catch { /* private mode */ }
  },
  del(k) { try { sessionStorage.removeItem(k); localStorage.removeItem(k); } catch { /* ignore */ } },
};

// ---------- API ----------
export class ApiError extends Error {
  constructor(message, status, code) { super(message); this.status = status; this.code = code; }
}
const BASE = (document.querySelector('meta[name="exerlio-api"]')?.content || '/api/exerlio/v1/').replace(/\/?$/, '/');
export const api = {
  token: store.get('cc.token'),
  onAuthLost: null,
  onPasswordChange: null,
  async req(method, path, body, { blob = false } = {}) {
    const headers = { Accept: blob ? 'text/csv' : 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (this.token) headers.Authorization = `Staff ${this.token}`;
    let res;
    try {
      res = await fetch(BASE + path.replace(/^\//, ''), { method, headers, body: body !== undefined ? JSON.stringify(body) : undefined });
    } catch {
      throw new ApiError('Can’t reach the server. Check your connection and try again.', 0);
    }
    if (blob && res.ok) return res.blob();
    let data = null;
    try { data = await res.json(); } catch { data = null; }
    if (!res.ok) {
      const msg = (data && (data.message || data.detail)) || `Something went wrong (${res.status}).`;
      if (res.status === 401 && this.onAuthLost && !path.startsWith('admin/auth/login')) this.onAuthLost(msg);
      if (res.status === 403 && data?.code === 'password_change' && this.onPasswordChange) this.onPasswordChange();
      throw new ApiError(msg, res.status, data?.code);
    }
    return data;
  },
  get(p) { return this.req('GET', p); },
  post(p, b = {}) { return this.req('POST', p, b); },
  patch(p, b = {}) { return this.req('PATCH', p, b); },
  del(p) { return this.req('DELETE', p); },
};

// ---------- formatting ----------
const NF = new Intl.NumberFormat('en-IN');
export const num = (n) => (n == null ? '—' : NF.format(n));
export const pct = (n) => (n == null ? '—' : `${n}%`);
export function change(n, { suffix = 'vs previous' } = {}) {
  if (n == null) return h`<span class="muted">New</span>`;
  const cls = n > 0 ? 'up' : n < 0 ? 'down' : 'muted';
  return h`<span class="${cls}">${n > 0 ? '+' : ''}${n}%</span> <span class="muted">${suffix}</span>`;
}
export const qs = (o) => Object.entries(o).filter(([, v]) => v !== '' && v != null).map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
export const initials = (name = '') => name.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0]).join('').toUpperCase() || '?';

const STATUS_COLOR = {
  active: 'green', restricted: 'amber', suspended: 'red', open: 'orange', in_progress: 'blue', waiting: 'amber',
  escalated: 'red', resolved: 'green', closed: 'plain', urgent: 'red', high: 'orange', medium: 'blue', low: 'plain',
  draft: 'amber', sent: 'green', invited: 'amber', disabled: 'red',
};
export const pill = (key, label) => h`<span class="pill ${STATUS_COLOR[key] || ''}">${label || key}</span>`;

export function avatar(u, cls = '') {
  if (!u) return h`<div class="avatar light ${cls}">?</div>`;
  return u.avatar ? h`<div class="avatar ${cls}"><img src="${u.avatar}" alt="" loading="lazy"></div>`
    : h`<div class="avatar light ${cls}">${u.initials || initials(u.name)}</div>`;
}
export function person(u, sub) {
  if (!u) return h`<span class="muted">No app user</span>`;
  return h`<div class="person">${avatar(u)}<div style="min-width:0"><strong>${u.name}</strong><small>${sub ?? `@${u.handle}`}</small></div></div>`;
}

// ---------- toast / modal ----------
export function toast(msg, err = false) {
  $$('.toast').forEach((t) => t.remove());
  const t = document.createElement('div');
  t.className = `toast${err ? ' err' : ''}`;
  t.setAttribute('role', 'status');
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), err ? 5200 : 3200);
}
export const fail = (e) => toast(e?.message || String(e), true);

/** Opens a modal. `onSave(body)` may return false to keep it open. Resolves when closed. */
export function modal({ title, body, save = 'Save', cancel = 'Cancel', danger = false, onSave, onOpen, wide = false }) {
  return new Promise((resolve) => {
    const bg = document.createElement('div');
    bg.className = 'modal-bg';
    bg.innerHTML = String(h`<div class="modal" role="dialog" aria-modal="true" aria-label="${title}" style="${wide ? 'width:min(720px,100%)' : ''}">
      <header><h2>${title}</h2><button class="x" data-x aria-label="Close">×</button></header>
      <div class="body">${body}</div>
      <footer>${cancel ? h`<button class="btn light" data-x>${cancel}</button>` : ''}${save ? h`<button class="btn ${danger ? 'danger' : 'orange'}" data-save>${save}</button>` : ''}</footer>
    </div>`);
    const close = (v) => { bg.remove(); document.removeEventListener('keydown', onKey); resolve(v); };
    const onKey = (e) => { if (e.key === 'Escape') close(null); };
    document.addEventListener('keydown', onKey);
    bg.addEventListener('click', (e) => { if (e.target === bg || e.target.closest('[data-x]')) close(null); });
    const btn = bg.querySelector('[data-save]');
    btn?.addEventListener('click', async () => {
      if (!onSave) return close(true);
      btn.disabled = true;
      try {
        const r = await onSave(bg.querySelector('.body'));
        if (r !== false) close(r ?? true);
      } catch (e) { fail(e); } finally { btn.disabled = false; }
    });
    document.body.appendChild(bg);
    onOpen?.(bg.querySelector('.body'));
    (bg.querySelector('.body input, .body textarea, .body select') || btn)?.focus();
  });
}
export const confirm = (title, text, save = 'Confirm', danger = false) => modal({ title, body: h`<p style="margin:4px 0 8px">${text}</p>`, save, danger });

// ---------- icons (stroke, 24 grid) ----------
const P = {
  home: 'M3 10.5 12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z',
  users: 'M16 19v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1M9.5 10a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7M21 19v-1a4 4 0 0 0-3-3.9M15.5 3.1a3.5 3.5 0 0 1 0 6.8',
  ticket: 'M4 5h16v4a3 3 0 0 0 0 6v4H4v-4a3 3 0 0 0 0-6zM13 5v14',
  chart: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  pulse: 'M3 12h4l3-8 4 16 3-8h4',
  flag: 'M5 21V4m0 0h11l-2 4 2 4H5',
  megaphone: 'M3 10v4h3l7 5V5L6 10zM17 8a5 5 0 0 1 0 8',
  team: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1',
  shield: 'M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z',
  log: 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  server: 'M3 4h18v6H3zM3 14h18v6H3zM7 7h.01M7 17h.01',
  key: 'M15 7a4 4 0 1 1-3.9 5H3v3h3v3h3v-3h2.1A4 4 0 0 1 15 7z',
  menu: 'M3 6h18M3 12h18M3 18h18',
  out: 'M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 17l5-5-5-5M15 12H3',
  bell: 'M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 20a2 2 0 0 0 4 0',
  run: 'M13 4a2 2 0 1 0 4 0 2 2 0 0 0-4 0M7 21l3-6 3 2v4M6 12l3-4 4 1 3 4 3 1',
  food: 'M7 3v8a2 2 0 0 0 4 0V3M9 11v10M17 3c-2 0-3 3-3 6s1 4 3 4v8',
  download: 'M12 4v12M6 10l6 6 6-6M4 20h16',
  plus: 'M12 5v14M5 12h14',
  refresh: 'M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5',
};
export const icon = (name, cls = '') => raw(`<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${P[name] || ''}"/></svg>`);

// ---------- charts ----------
const COLORS = ['#ff6b00', '#111214', '#2a5bd7', '#15805a'];

/** Line chart with hover tooltip. series: [{name, values, color?}] sharing `labels`. */
export function lineChart(el, { labels, series, height = 220, area = true }) {
  const W = 640, H = height, L = 34, R = 10, T = 12, B = 26;
  const max = Math.max(1, ...series.flatMap((s) => s.values));
  const nice = max <= 4 ? 4 : Math.ceil(max / 4) * 4;
  const x = (i) => L + (labels.length < 2 ? 0 : (i * (W - L - R)) / (labels.length - 1));
  const y = (v) => T + (H - T - B) * (1 - v / nice);
  let svg = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" role="img" aria-label="${esc(series.map((s) => s.name).join(', '))} chart">`;
  for (let g = 0; g <= 4; g++) {
    const v = (nice * g) / 4, yy = y(v);
    svg += `<line class="grid-line" x1="${L}" x2="${W - R}" y1="${yy}" y2="${yy}"/><text class="axis" x="${L - 6}" y="${yy + 3}" text-anchor="end">${Math.round(v)}</text>`;
  }
  const step = Math.max(1, Math.ceil(labels.length / 7));
  labels.forEach((lb, i) => { if (i % step === 0 || i === labels.length - 1) svg += `<text class="axis" x="${x(i)}" y="${H - 6}" text-anchor="middle">${esc(lb)}</text>`; });
  series.forEach((s, si) => {
    const c = s.color || COLORS[si % COLORS.length];
    const pts = s.values.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`);
    if (area && si === 0 && pts.length) svg += `<path d="M${pts[0]} L${pts.join(' L')} L${x(s.values.length - 1)},${y(0)} L${x(0)},${y(0)}Z" fill="${c}" opacity=".09"/>`;
    svg += `<polyline points="${pts.join(' ')}" fill="none" stroke="${c}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>`;
  });
  svg += `<line class="hover-line" x1="0" x2="0" y1="${T}" y2="${H - B}" stroke="#c9cacd" stroke-dasharray="3 3" opacity="0"/></svg><div class="tip"></div>`;
  el.classList.add('chart');
  el.style.height = `${H}px`;
  el.innerHTML = svg;
  const svgEl = el.querySelector('svg'), tip = el.querySelector('.tip'), hl = el.querySelector('.hover-line');
  el.onmousemove = (e) => {
    const r = svgEl.getBoundingClientRect();
    const px = ((e.clientX - r.left) / r.width) * W;
    const i = Math.max(0, Math.min(labels.length - 1, Math.round(((px - L) / (W - L - R)) * (labels.length - 1))));
    hl.setAttribute('x1', x(i)); hl.setAttribute('x2', x(i)); hl.setAttribute('opacity', '1');
    tip.innerHTML = `<b>${esc(labels[i])}</b><br>${series.map((s) => `${esc(s.name)}: ${num(s.values[i])}`).join('<br>')}`;
    tip.style.left = `${(x(i) / W) * r.width}px`;
    tip.style.top = `${(y(Math.max(...series.map((s) => s.values[i]))) / H) * r.height}px`;
    tip.style.opacity = 1;
  };
  el.onmouseleave = () => { tip.style.opacity = 0; hl.setAttribute('opacity', '0'); };
}

export function legend(series) {
  return h`<div class="legend">${series.map((s, i) => h`<span><i style="background:${s.color || COLORS[i % COLORS.length]}"></i>${s.name}</span>`)}</div>`;
}

export function spark(values, color = '#ff6b00') {
  const W = 110, H = 28, max = Math.max(1, ...values);
  const pts = values.map((v, i) => `${((i * (W - 2)) / Math.max(1, values.length - 1) + 1).toFixed(1)},${(H - 2 - (v / max) * (H - 4)).toFixed(1)}`);
  return raw(`<svg class="spark" viewBox="0 0 ${W} ${H}" aria-hidden="true"><polyline points="${pts.join(' ')}" fill="none" stroke="${color}" stroke-width="1.6" stroke-linejoin="round"/></svg>`);
}

export function bars(rows, { orange = false, valueKey = 'users', labelKey = 'label' } = {}) {
  const max = Math.max(1, ...rows.map((r) => r[valueKey]));
  if (!rows.length) return h`<div class="empty">No data yet.</div>`;
  return h`${rows.map((r) => h`<div class="bar-row"><span title="${r[labelKey]}" style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${r[labelKey]}</span>
    <div class="track"><div class="fill ${orange ? 'o' : ''}" style="width:${(r[valueKey] * 100) / max}%"></div></div><span class="n">${num(r[valueKey])}</span></div>`)}`;
}

export const skeleton = (n = 3, hgt = 90) => h`<div class="grid g4">${Array.from({ length: n }, () => h`<div class="skeleton" style="height:${hgt}px"></div>`)}</div>`;

export function pager(meta, onGo) {
  const wrap = document.createElement('div');
  wrap.className = 'pager';
  wrap.innerHTML = String(h`<span>${num(meta.total)} total · page ${meta.page} of ${meta.pages}</span>
    <span class="row"><button class="btn light sm" data-p="${meta.page - 1}" ${meta.page <= 1 ? 'disabled' : ''}>Previous</button>
    <button class="btn light sm" data-p="${meta.page + 1}" ${meta.page >= meta.pages ? 'disabled' : ''}>Next</button></span>`);
  wrap.addEventListener('click', (e) => { const b = e.target.closest('[data-p]'); if (b && !b.disabled) onGo(Number(b.dataset.p)); });
  return wrap;
}

export function debounce(fn, ms = 300) {
  let t;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

export function download(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500);
}

export async function copy(text) {
  try { await navigator.clipboard.writeText(text); toast('Copied'); } catch { toast('Copy failed. Select it and copy by hand.', true); }
}

/** Ask the shell to refresh the sidebar counts (tickets, reports). */
export const refreshBadgesSafe = () => window.dispatchEvent(new Event('cc:badges'));
