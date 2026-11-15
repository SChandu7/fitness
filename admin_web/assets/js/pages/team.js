import { $, api, confirm, copy, h, modal, mount, pill, toast } from '../core.js';

function showSecret(title, member, pw) {
  return modal({
    title, save: 'Done', cancel: '',
    body: h`<p style="margin-top:0">Give <b>${member}</b> this temporary password privately (in person or a direct message, not a group chat).
      They'll be asked to set their own the first time they sign in.</p>
      <div class="secret"><span class="grow">${pw}</span><button class="btn light sm" id="cp">Copy</button></div>
      <p class="small muted">It won't be shown again. If it's lost, reset the password.</p>`,
    onOpen: (m) => { $('#cp', m).onclick = () => copy(pw); },
    onSave: () => true,
  }).then(() => {});
}

export async function render(ctx) {
  const { root, session } = ctx;
  const me = session.me.staff;
  const canManage = session.can('staff.manage');
  let d;
  async function load() {
    d = await api.get('admin/team/');
    const roleOpts = (cur) => d.roles.filter((r) => me.role === 'owner' || r.key !== 'owner').map((r) => h`<option value="${r.key}" ${r.key === cur ? 'selected' : ''}>${r.label}</option>`);
    mount(root, h`
      <div class="page-head"><div><div class="eyebrow">Administration</div><h1>Team and roles</h1>
        <div class="sub">Every person gets their own login. Never share one.</div></div>
        <div class="actions">${canManage ? h`<button class="btn orange" id="add">Add team member</button>` : ''}</div></div>
      <section class="card flush"><div class="table-wrap"><table><thead><tr><th>Person</th><th>Role</th><th>Status</th><th>Last sign-in</th>${canManage ? h`<th></th>` : ''}</tr></thead>
        <tbody>${d.items.map((s) => h`<tr><td><div class="person"><div class="avatar light">${s.initials}</div><div><strong>${s.name}${s.id === me.id ? ' (you)' : ''}</strong><small>${s.email}</small></div></div></td>
          <td>${s.role_label}</td>
          <td>${s.active ? (s.must_change_password ? pill('invited', 'Hasn’t signed in yet') : pill('active', 'Active')) : pill('disabled', 'Disabled')}</td>
          <td class="small">${s.last_login ? s.last_login.rel : h`<span class="muted">Never</span>`}</td>
          ${canManage ? h`<td><div class="row">${s.id !== me.id && (me.role === 'owner' || s.role !== 'owner') ? h`
            <select class="select" data-role="${s.id}" aria-label="Role for ${s.name}">${roleOpts(s.role)}</select>
            <button class="btn light sm" data-reset="${s.id}">Reset password</button>
            <button class="btn ${s.active ? 'danger' : 'light'} sm" data-active="${s.id}" data-on="${s.active ? '0' : '1'}">${s.active ? 'Disable' : 'Enable'}</button>` : ''}</div></td>` : ''}</tr>`)}</tbody></table></div></section>

      <section class="card mt"><div class="card-head"><div><div class="card-title">What each role can do</div>
        <div class="card-note">Interns and support see masked email and phone. Health answers are visible only to owners and admins; women's health data is never shown.</div></div></div>
        <div class="grid g3" style="margin-bottom:16px">${d.roles.map((r) => h`<div style="border:1px solid var(--line);border-radius:10px;padding:12px"><b>${r.label}</b><p class="small muted" style="margin:4px 0 0">${r.summary}</p></div>`)}</div>
        <div class="table-wrap"><table class="perm-grid"><thead><tr><th>Permission</th>${d.roles.map((r) => h`<th>${r.label}</th>`)}</tr></thead>
          <tbody>${Object.entries(d.permission_labels).map(([k, l]) => h`<tr><td>${l}</td>${d.roles.map((r) => h`<td>${r.permissions.includes(k) ? h`<span class="tick" aria-label="yes">✓</span>` : h`<span class="muted" aria-label="no">·</span>`}</td>`)}</tr>`)}</tbody></table></div></section>`);
  }
  root.addEventListener('change', async (e) => {
    const sel = e.target.closest('[data-role]');
    if (!sel) return;
    try { await api.patch(`admin/team/${sel.dataset.role}/`, { role: sel.value }); toast('Role updated'); } catch (err) { toast(err.message, true); }
    load();
  });
  root.addEventListener('click', async (e) => {
    if (e.target.closest('#add')) {
      const r = await modal({
        title: 'Add team member', save: 'Create login',
        body: h`<div class="field"><label for="tn">Full name</label><input class="input" id="tn" autocomplete="off"></div>
          <div class="field"><label for="te">Work email</label><input class="input" id="te" type="email" autocomplete="off"></div>
          <div class="field"><label for="tr">Role</label><select class="select" id="tr">${d.roles.filter((x) => me.role === 'owner' || x.key !== 'owner').map((x) => h`<option value="${x.key}" ${x.key === 'intern' ? 'selected' : ''}>${x.label}: ${x.summary}</option>`)}</select></div>`,
        onSave: (m) => api.post('admin/team/', { name: $('#tn', m).value, email: $('#te', m).value, role: $('#tr', m).value }),
      });
      if (r) { await load(); showSecret('Login created', r.member.name, r.temp_password); }
      return;
    }
    const rs = e.target.closest('[data-reset]'), ac = e.target.closest('[data-active]');
    if (rs) {
      const s = d.items.find((x) => x.id === Number(rs.dataset.reset));
      if (!await confirm('Reset password?', `${s.name} gets a new temporary password and is signed out everywhere.`, 'Reset')) return;
      try { const r = await api.post(`admin/team/${s.id}/reset/`); await load(); showSecret('Password reset', s.name, r.temp_password); } catch (err) { toast(err.message, true); }
    }
    if (ac) {
      const s = d.items.find((x) => x.id === Number(ac.dataset.active));
      const on = ac.dataset.on === '1';
      if (!on && !await confirm('Disable login?', `${s.name} is signed out and can't sign in until re-enabled. Their past actions stay in the audit log.`, 'Disable', true)) return;
      try { await api.patch(`admin/team/${s.id}/`, { active: on }); toast(on ? 'Login enabled' : 'Login disabled'); } catch (err) { toast(err.message, true); }
      load();
    }
  });
  await load();
}
