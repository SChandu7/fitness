import { $, api, debounce, h, mount, pager, qs } from '../core.js';

export async function render(ctx) {
  const { root } = ctx;
  const f = { q: '', action: '', page: 1 };
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Administration</div><h1>Audit log</h1>
      <div class="sub">Who did what, and when. Entries can't be edited or deleted from here.</div></div></div>
    <section class="card flush"><div class="toolbar" style="padding:14px 14px 0">
      <input class="input search" id="q" placeholder="Search person, action or summary" aria-label="Search audit log">
      <select class="select" id="ac" aria-label="Action"><option value="">All actions</option></select></div>
      <div id="tbl"><div class="loading">Loading…</div></div></section>`);
  const box = $('#tbl', root);
  async function load() {
    const d = await api.get(`admin/audit/?${qs(f)}`);
    const sel = $('#ac', root);
    if (sel.options.length === 1) {
      const groups = [...new Set(d.actions.map((a) => a.split('.')[0]))];
      sel.insertAdjacentHTML('beforeend', String(h`${groups.map((g) => h`<option value="${g}.">${g}: all</option>`)}${d.actions.map((a) => h`<option value="${a}">${a}</option>`)}`));
    }
    if (!d.items.length) return mount(box, h`<div class="empty">No entries match.</div>`);
    mount(box, h`<div class="table-wrap"><table><thead><tr><th>When</th><th>Who</th><th>Action</th><th>What</th><th>Target</th><th>IP</th></tr></thead>
      <tbody>${d.items.map((a) => h`<tr><td class="small">${a.when.label}</td><td>${a.staff}</td><td><span class="pill plain mono">${a.action}</span></td>
        <td style="white-space:normal;max-width:420px">${a.summary}</td><td class="small mono">${a.target}</td><td class="small mono muted">${a.ip}</td></tr>`)}</tbody></table></div>`);
    box.appendChild(pager(d, (p) => { f.page = p; load(); }));
  }
  $('#q', root).addEventListener('input', debounce((e) => { f.q = e.target.value.trim(); f.page = 1; load(); }));
  $('#ac', root).onchange = (e) => { f.action = e.target.value; f.page = 1; load(); };
  await load();
}
