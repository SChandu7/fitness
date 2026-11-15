import { api, bars, h, mount, num } from '../core.js';

export async function render(ctx) {
  const { root } = ctx;
  const d = await api.get('admin/system/');
  const dbState = d.db_ms < 50 ? ['green', 'Fast'] : d.db_ms < 250 ? ['amber', 'Slow'] : ['red', 'Very slow'];
  const evState = !d.last_event ? ['plain', 'No events yet'] : d.events_1h ? ['green', 'Receiving'] : ['amber', 'Quiet for an hour'];
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Administration</div><h1>System status</h1>
      <div class="sub">Checked just now from the live server.</div></div>
      <button class="btn light" id="again">Check again</button></div>
    <div class="grid g4">
      <div class="stat"><div class="label">Database response <span class="pill ${dbState[0]}">${dbState[1]}</span></div><div class="value">${d.db_ms} ms</div><div class="foot">${d.db_vendor}</div></div>
      <div class="stat"><div class="label">Usage events <span class="pill ${evState[0]}">${evState[1]}</span></div><div class="value">${num(d.events_1h)}</div><div class="foot">last hour · ${num(d.events_24h)} in 24 h</div></div>
      <div class="stat"><div class="label">Last event received</div><div class="value" style="font-size:20px">${d.last_event ? d.last_event.rel : '—'}</div><div class="foot">${d.last_event ? d.last_event.label : 'Starts with app 3.3'}</div></div>
      <div class="stat"><div class="label">Team sessions open</div><div class="value">${num(d.sessions)}</div><div class="foot">Control Centre sign-ins</div></div>
    </div>
    <div class="grid g2 mt">
      <section class="card"><div class="card-title" style="margin-bottom:12px">App versions in use (last 7 days)</div>
        ${d.versions.length ? bars(d.versions.map((v) => ({ label: `${v.platform} ${v.version}`, users: v.users }))) : h`<div class="empty">Reported from app 3.3 on.</div>`}</section>
      <section class="card"><div class="card-title" style="margin-bottom:12px">Server</div><dl class="kv">
        <dt>Server time</dt><dd>${d.server_time.label} (India)</dd><dt>Database schema</dt><dd class="mono">${d.migration}</dd>
        <dt>Python · Django</dt><dd>${d.python} · ${d.django}</dd>
        <dt>Users</dt><dd>${num(d.tables.users)}</dd><dt>Events stored</dt><dd>${num(d.tables.events)}</dd>
        <dt>Tickets</dt><dd>${num(d.tables.tickets)}</dd><dt>Audit entries</dt><dd>${num(d.tables.audit)}</dd></dl></section>
    </div>`);
  root.querySelector('#again').onclick = () => render(ctx);
}
