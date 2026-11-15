import { $, api, avatar, debounce, download, fail, h, modal, mount, num, pager, person, pill, qs, toast } from '../core.js';

const STATUS = { active: 'Active', restricted: 'Restricted', suspended: 'Suspended' };
const KEY_EVENTS = new Set(['live_finish', 'workout_done', 'scan_saved', 'post_create', 'ticket_create', 'paywall_tap', 'signup', 'onboarding_done', 'api_error']);

export async function render(ctx) {
  return ctx.id ? detail(ctx) : list(ctx);
}

// ---------- list ----------
async function list(ctx) {
  const { root, session } = ctx;
  const f = { q: ctx.query.q || '', status: '', platform: '', sort: 'joined', real: '1', page: 1 };
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Users</div><h1>Users</h1>
      <div class="sub">Find a member, see how they use Exerlio and act on their account.</div></div>
      <div class="actions">${session.can('users.export') ? h`<button class="btn light" id="exp">Export CSV</button>` : ''}</div></div>
    <div class="notice gray">${session.can('users.contact') ? 'You can see full contact details. Every full-profile view is recorded in the audit log.'
      : 'Email and mobile are partly hidden for your role. Search still works with a full email or mobile number.'}</div>
    <section class="card flush">
      <div class="toolbar" style="padding:14px 14px 0">
        <input class="input search" id="q" placeholder="Name, @handle, exact email or mobile" value="${f.q}" aria-label="Search users">
        <select class="select" id="st" aria-label="Status"><option value="">All statuses</option>${Object.entries(STATUS).map(([k, v]) => h`<option value="${k}">${v}</option>`)}</select>
        <select class="select" id="pl" aria-label="Platform"><option value="">All platforms</option><option value="android">Android</option><option value="ios">iPhone</option></select>
        <select class="select" id="so" aria-label="Sort"><option value="joined">Newest first</option><option value="active">Recently active</option><option value="name">Name A–Z</option></select>
        <label class="check"><input type="checkbox" id="real" checked> Hide demo accounts</label>
      </div>
      <div id="tbl"><div class="loading">Loading…</div></div></section>`);
  const load = async () => {
    const box = $('#tbl', root);
    try {
      const d = await api.get(`admin/users/?${qs(f)}`);
      if (!d.items.length) return mount(box, h`<div class="empty">No users match.</div>`);
      mount(box, h`<div class="table-wrap"><table><thead><tr><th>User</th><th>Contact</th><th>Status</th><th>Joined</th><th>Last active</th><th>App</th><th>Goals</th></tr></thead>
        <tbody>${d.items.map((u) => h`<tr class="click" data-id="${u.id}"><td>${person(u, `@${u.handle}${u.seed ? ' · demo' : ''}`)}</td>
          <td class="small">${u.email || '—'}<br><span class="muted">${u.mobile || ''}</span></td>
          <td>${pill(u.status, STATUS[u.status])}${u.onboarded ? '' : h` <span class="pill plain">Setup unfinished</span>`}</td>
          <td class="small">${u.joined.label.split(',')[0]}</td><td class="small">${u.last_active ? u.last_active.rel : h`<span class="muted">Never</span>`}</td>
          <td class="small">${u.platform ? `${u.platform} ${u.version}` : h`<span class="muted">—</span>`}</td>
          <td class="small" style="max-width:220px;white-space:normal">${u.goals.slice(0, 2).join(', ')}</td></tr>`)}</tbody></table></div>`);
      box.appendChild(pager(d, (p) => { f.page = p; load(); }));
    } catch (e) { mount(box, h`<div class="empty">${e.message}</div>`); }
  };
  const reload = () => { f.page = 1; load(); };
  $('#q', root).addEventListener('input', debounce((e) => { f.q = e.target.value.trim(); reload(); }));
  $('#st', root).onchange = (e) => { f.status = e.target.value; reload(); };
  $('#pl', root).onchange = (e) => { f.platform = e.target.value; reload(); };
  $('#so', root).onchange = (e) => { f.sort = e.target.value; reload(); };
  $('#real', root).onchange = (e) => { f.real = e.target.checked ? '1' : ''; reload(); };
  $('#tbl', root).addEventListener('click', (e) => { const tr = e.target.closest('tr[data-id]'); if (tr) location.hash = `#/users/${tr.dataset.id}`; });
  $('#exp', root)?.addEventListener('click', async () => {
    try { download(await api.req('GET', 'admin/users/export/', undefined, { blob: true }), `exerlio-users-${new Date().toISOString().slice(0, 10)}.csv`); toast('Export ready. It was recorded in the audit log.'); } catch (e) { fail(e); }
  });
  await load();
}

// ---------- detail ----------
async function detail(ctx) {
  const { root, session, id } = ctx;
  const u = await api.get(`admin/users/${id}/`);
  const tab = ctx.query.tab || 'profile';
  const tabs = [['profile', 'Profile'], ...(session.can('users.timeline') ? [['activity', 'Activity timeline']] : []), ['tickets', `Tickets (${u.tickets.length})`]];
  mount(root, h`
    <div class="page-head"><div class="row" style="gap:14px">${avatar(u, 'lg')}<div>
        <div class="eyebrow"><a href="#/users" style="color:inherit">Users</a> / @${u.handle}</div>
        <h1 style="margin:2px 0">${u.name}</h1>
        <div class="row wrap small">${pill(u.status, STATUS[u.status])}${u.seed ? h`<span class="pill plain">Demo account</span>` : ''}
          <span class="muted">Joined ${u.joined.label} · last active ${u.last_active ? u.last_active.rel : 'never'}</span></div></div></div>
      <div class="actions">
        ${session.can('notify.user') ? h`<button class="btn light" id="notify">Send notification</button>` : ''}
        ${session.can('users.status') ? h`<button class="btn ${u.status === 'active' ? 'danger' : 'light'}" id="status">${u.status === 'active' ? 'Restrict or suspend' : 'Change status'}</button>` : ''}
      </div></div>
    ${u.status !== 'active' ? h`<div class="notice"><b>${STATUS[u.status]}:</b> ${u.status_reason || 'no reason recorded'}. ${u.status === 'suspended' ? 'They are signed out and can’t sign in.' : 'They can use the app but can’t post, comment or message.'}</div>` : ''}
    <div class="tabs" role="tablist">${tabs.map(([k, l]) => h`<button role="tab" class="${k === tab ? 'on' : ''}" data-tab="${k}">${l}</button>`)}</div>
    <div id="tabbody"></div>`);
  root.querySelector('.tabs').onclick = (e) => {
    const b = e.target.closest('[data-tab]');
    if (b) location.hash = `#/users/${id}?tab=${b.dataset.tab}`;
  };
  const body = $('#tabbody', root);
  if (tab === 'activity') await timeline(body, u);
  else if (tab === 'tickets') ticketsTab(body, u);
  else profile(body, u);

  $('#notify', root)?.addEventListener('click', () => modal({
    title: `Notify ${u.name}`, save: 'Send',
    body: h`<div class="field"><label for="nt">Message</label><textarea class="input" id="nt" maxlength="200" placeholder="Shows in their Notifications in the app"></textarea>
      <div class="hint">Up to 200 characters. Recorded in the audit log.</div></div>`,
    onSave: async (b) => { const r = await api.post(`admin/users/${id}/notify/`, { text: $('#nt', b).value.trim() }); toast(r.message); },
  }));
  $('#status', root)?.addEventListener('click', async () => {
    const ok = await modal({
      title: `Account status · @${u.handle}`, save: 'Apply',
      body: h`<div class="field"><label for="ns">Status</label><select class="select" id="ns">
          <option value="active" ${u.status === 'active' ? 'selected' : ''}>Active: full access</option>
          <option value="restricted" ${u.status === 'restricted' ? 'selected' : ''}>Restricted: can't post, comment or message</option>
          <option value="suspended" ${u.status === 'suspended' ? 'selected' : ''}>Suspended: signed out, can't sign in</option></select></div>
        <div class="field"><label for="nr">Reason</label><input class="input" id="nr" maxlength="200" placeholder="Required unless setting back to active">
          <div class="hint">Recorded in the audit log. Restricted users get a short in-app note.</div></div>`,
      onSave: async (b) => { const r = await api.post(`admin/users/${id}/status/`, { status: $('#ns', b).value, reason: $('#nr', b).value }); toast(r.message); },
    });
    if (ok) render(ctx);
  });
}

function profile(body, u) {
  const s = u.stats, p = u.profile;
  mount(body, h`
    <div class="grid g4">${[['Activities', s.activities, `${num(s.activities_30d)} in 30 days`], ['Meal scans', s.scans, ''], ['Streak', s.streak, `Best ${num(s.best_streak)} days`],
      ['App opens (30 days)', s.sessions_30d, 'From app 3.3 on']].map(([l, v, f]) => h`<div class="stat"><div class="label">${l}</div><div class="value">${num(v)}</div><div class="foot">${f}</div></div>`)}</div>
    <div class="grid g2 mt">
      <section class="card"><div class="card-title" style="margin-bottom:12px">Profile</div><dl class="kv">
        <dt>Email</dt><dd>${u.email || '—'}</dd><dt>Mobile</dt><dd>${u.mobile || '—'}</dd>
        <dt>Goals</dt><dd>${p.goals.join(', ') || '—'}</dd><dt>Level</dt><dd>${p.level}</dd>
        <dt>Sex · age</dt><dd>${p.sex} · ${p.age}</dd><dt>Training days</dt><dd>${p.days_per_week} a week</dd>
        <dt>Sports</dt><dd>${p.sports.join(', ') || '—'}</dd><dt>Connected</dt><dd>${p.devices.join(', ') || 'Nothing connected'}</dd>
        <dt>App</dt><dd>${u.platform ? `${u.platform} ${u.version}` : 'Not reported yet'}</dd><dt>Private profile</dt><dd>${u.private ? 'Yes' : 'No'}</dd>
        ${u.location ? h`<dt>Location</dt><dd>${u.location}</dd>` : ''}${u.bio ? h`<dt>Bio</dt><dd>${u.bio}</dd>` : ''}</dl></section>
      <section class="card"><div class="card-title" style="margin-bottom:12px">Social</div><dl class="kv">
        <dt>Posts · reels</dt><dd>${num(s.posts)} · ${num(s.reels)}</dd><dt>Followers</dt><dd>${num(s.followers)}</dd><dt>Following</dt><dd>${num(s.following)}</dd>
        <dt>Clubs</dt><dd>${num(s.clubs)}</dd><dt>Reports on their posts</dt><dd>${s.reports_against ? h`<span class="pill red">${s.reports_against}</span>` : '0'}</dd></dl>
        ${u.health_visible ? h`<div class="card-title" style="margin:18px 0 10px">Health answers</div><dl class="kv">
          <dt>Conditions</dt><dd>${(u.health.conditions || []).join(', ') || 'None'}${u.health.condition_other ? ` · ${u.health.condition_other}` : ''}</dd>
          <dt>Food alerts</dt><dd>${(u.health.allergies || []).join(', ') || 'None'}</dd><dt>Medications</dt><dd>${u.health.medications || '—'}</dd></dl>
          <p class="small muted">Sensitive. Only use this to answer the user's own support request.</p>`
          : h`<p class="small muted" style="margin-top:16px">Health answers are hidden for your role. Women's health data is never shown here.</p>`}
      </section></div>`);
}

async function timeline(body, u) {
  let days = 7;
  const load = async () => {
    mount(body, h`<div class="loading">Loading activity…</div>`);
    const d = await api.get(`admin/users/${u.id}/timeline/?days=${days}`);
    mount(body, h`<div class="toolbar"><div class="seg" id="rng">${[1, 7, 30].map((n) => h`<button class="${n === days ? 'on' : ''}" data-d="${n}">${n === 1 ? 'Today' : `${n} days`}</button>`)}</div>
      <span class="spacer"></span><span class="small muted">${num(d.sessions.length)} visits · ${num(d.total_events)} events · viewing this is recorded</span></div>
      ${d.sessions.length ? d.sessions.map((s, i) => h`<details class="session" ${i < 3 ? 'open' : ''}><summary>
          <b>${s.start.label}</b><span class="pill plain">${s.minutes} min</span><span class="muted small">${s.count} actions · ${s.platform || 'app'} ${s.version || ''}</span></summary>
          <ol>${s.events.map((e) => h`<li class="${KEY_EVENTS.has(e.name) ? 'key' : ''}"><time>${e.time}</time><span>${e.text}</span></li>`)}</ol></details>`)
        : h`<div class="card empty">No in-app activity in this period. Activity is recorded from app version 3.3 on.</div>`}`);
    $('#rng', body).onclick = (e) => { const b = e.target.closest('[data-d]'); if (b) { days = Number(b.dataset.d); load(); } };
  };
  await load();
}

function ticketsTab(body, u) {
  mount(body, u.tickets.length ? h`<section class="card flush"><div class="table-wrap"><table><thead><tr><th>Ticket</th><th>Subject</th><th>Status</th><th>Updated</th></tr></thead>
    <tbody>${u.tickets.map((t) => h`<tr class="click" data-t="${t.id}"><td class="mono">${t.number}</td><td>${t.subject}</td><td>${pill(t.status, t.status_label)}</td><td class="small">${t.updated.rel}</td></tr>`)}</tbody></table></div></section>`
    : h`<div class="card empty">No support tickets from this user.</div>`);
  body.onclick = (e) => { const tr = e.target.closest('[data-t]'); if (tr) location.hash = `#/tickets/${tr.dataset.t}`; };
}
