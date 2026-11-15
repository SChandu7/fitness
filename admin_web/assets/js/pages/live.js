import { $, api, h, mount, num, person } from '../core.js';

export async function render(ctx) {
  const { root, session } = ctx;
  let paused = false;
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Analytics</div><h1>Live activity</h1>
      <div class="sub">What people are doing in the app right now. Refreshes every 10 seconds.</div></div>
      <div class="actions"><span class="pill green" id="online"><span class="live-dot"></span>…</span>
        <button class="btn light" id="pause">Pause</button></div></div>
    <section class="card flush"><div class="table-wrap"><table><thead><tr><th>Time</th><th>Who</th><th>What happened</th><th>App</th></tr></thead>
      <tbody id="rows"><tr><td colspan="4" class="loading">Loading…</td></tr></tbody></table></div></section>`);
  const load = async () => {
    if (paused || document.hidden) return;
    const d = await api.get('admin/analytics/live/');
    $('#online', root).innerHTML = String(h`<span class="live-dot"></span> ${num(d.online)} using the app now`);
    mount($('#rows', root), d.items.length ? h`${d.items.map((e) => h`<tr class="${e.user && session.can('users.view') ? 'click' : ''}" data-u="${e.user ? e.user.id : ''}">
        <td class="small mono">${e.time}<br><span class="muted">${e.rel}</span></td>
        <td>${e.user ? person(e.user) : h`<span class="muted">Signed-out visitor</span>`}</td>
        <td>${e.text}</td><td class="small muted">${e.platform} ${e.version}</td></tr>`)}`
      : h`<tr><td colspan="4" class="empty">Nothing yet. Events arrive from app version 3.3 on.</td></tr>`);
  };
  $('#rows', root).onclick = (e) => { const tr = e.target.closest('tr[data-u]'); if (tr?.dataset.u && session.can('users.view')) location.hash = `#/users/${tr.dataset.u}?tab=activity`; };
  $('#pause', root).onclick = (e) => { paused = !paused; e.target.textContent = paused ? 'Resume' : 'Pause'; if (!paused) load(); };
  await load();
  const t = setInterval(() => load().catch(() => {}), 10000);
  ctx.cleanup = () => clearInterval(t);
}
