import { $, api, h, modal, mount, pager, person, refreshBadgesSafe, toast } from '../core.js';

const ACTIONS = {
  dismiss: ['Keep it', 'The content stays. The report is closed.'],
  remove: ['Remove', 'Deletes the content and tells the author why.'],
  remove_restrict: ['Remove and restrict author', 'Deletes it; the author can’t post, comment or message until restored.'],
  remove_suspend: ['Remove and suspend author', 'Deletes it and signs the author out. Use for serious or repeated abuse.'],
};

export async function render(ctx) {
  const { root, session } = ctx;
  let state = 'open', page = 1;
  const canAct = session.can('moderation.act');
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Safety</div><h1>Moderation</h1>
      <div class="sub">Posts and reels people reported. Check the content against the community rules, then decide.</div></div>
      <div class="seg" id="st"><button class="on" data-s="open">Needs review</button><button data-s="resolved">Handled</button></div></div>
    <div id="list"></div>`);
  const box = $('#list', root);
  async function load() {
    mount(box, h`<div class="loading">Loading…</div>`);
    const d = await api.get(`admin/reports/?state=${state}&page=${page}`);
    if (!d.items.length) return mount(box, h`<div class="card empty">${state === 'open' ? 'Nothing waiting. The community is behaving.' : 'No handled reports yet.'}</div>`);
    mount(box, h`${d.items.map((r) => {
      const t = r.target;
      return h`<section class="card mt"><div class="mod-card">
        <div class="mod-media">${t?.media_kind === 'image' ? h`<img src="${t.media}" alt="Reported image" loading="lazy">`
          : t?.media_kind === 'video' ? h`<video src="${t.media}" controls preload="metadata"></video>` : h`<span>No media</span>`}</div>
        <div style="min-width:0"><div class="row between wrap"><span class="pill red">Reported: ${r.reason}</span>
            <span class="small muted">${r.created.rel}${r.reports_on_target > 1 ? ` · ${r.reports_on_target} reports on this ${t?.type}` : ''}</span></div>
          <div class="row wrap" style="margin:12px 0;gap:22px"><div><div class="eyebrow">Author</div>${t?.author ? h`<a href="#/users/${t.author.id}" style="text-decoration:none">${person(t.author, `@${t.author.handle} · ${t.author.status}`)}</a>` : '—'}</div>
            <div><div class="eyebrow">Reported by</div>${person(r.reporter)}</div></div>
          ${t ? h`<div class="eyebrow" style="margin-bottom:6px">${t.type} · posted ${t.created.rel}</div><div class="quote">${t.text || '(no text)'}</div>` : h`<div class="quote muted">The content was already deleted.</div>`}
          ${state === 'open' && canAct ? h`<div class="row wrap" style="margin-top:14px">${Object.entries(ACTIONS).map(([k, [l]]) =>
            h`<button class="btn ${k === 'dismiss' ? 'light' : k === 'remove' ? '' : 'danger'} sm" data-act="${k}" data-id="${r.id}">${l}</button>`)}</div>` : ''}
        </div></div></section>`;
    })}`);
    box.appendChild(pager(d, (p) => { page = p; load(); }));
  }
  box.addEventListener('click', async (e) => {
    const b = e.target.closest('[data-act]');
    if (!b) return;
    const [label, help] = ACTIONS[b.dataset.act];
    const done = await modal({
      title: label, save: label, danger: b.dataset.act !== 'dismiss',
      body: h`<p class="small" style="margin-top:0">${help}</p>${b.dataset.act !== 'dismiss' ? h`<div class="field"><label for="why">Reason</label>
        <input class="input" id="why" maxlength="200" placeholder="e.g. Spam link, harassment, nudity"><div class="hint">The author sees this. It's also recorded in the audit log.</div></div>` : ''}`,
      onSave: async (m) => api.post(`admin/reports/${b.dataset.id}/`, { action: b.dataset.act, reason: $('#why', m)?.value || '' }),
    });
    if (done) { toast(done.message); refreshBadgesSafe(); load(); }
  });
  $('#st', root).onclick = (e) => {
    const b = e.target.closest('[data-s]');
    if (!b) return;
    state = b.dataset.s; page = 1;
    $('#st', root).querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b));
    load();
  };
  await load();
}
