import { $, api, h, mount, toast } from '../core.js';

export async function render(ctx) {
  const { root, session } = ctx;
  const s = session.me.staff;
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Account</div><h1>My account</h1><div class="sub">${s.name} · ${s.email} · ${s.role_label}</div></div></div>
    <div class="grid g2">
      <section class="card"><div class="card-title" style="margin-bottom:14px">Change password</div>
        <form id="pf" novalidate>
          <div class="field"><label for="c">Current password</label><input class="input" id="c" type="password" autocomplete="current-password"></div>
          <div class="field"><label for="n">New password</label><input class="input" id="n" type="password" autocomplete="new-password">
            <div class="hint">At least 10 characters with upper and lower case letters and a number.</div></div>
          <div class="field"><label for="n2">Repeat new password</label><input class="input" id="n2" type="password" autocomplete="new-password"></div>
          <button class="btn orange" type="submit">Change password</button></form></section>
      <section class="card"><div class="card-title" style="margin-bottom:14px">Your access</div>
        <p class="small muted" style="margin-top:0">What your role lets you do. Ask an owner or admin if you need more.</p>
        <ul class="small" style="padding-left:18px;line-height:1.9">${session.me.permissions.map((p) => h`<li class="mono">${p}</li>`)}</ul>
        <p class="small muted">Sessions end after 12 hours without use. Changing your password signs out your other sessions.</p></section>
    </div>`);
  $('#pf', root).addEventListener('submit', async (e) => {
    e.preventDefault();
    if ($('#n', root).value !== $('#n2', root).value) return toast('The new passwords don’t match.', true);
    try {
      const r = await api.post('admin/me/password/', { current: $('#c', root).value, new: $('#n', root).value });
      toast(r.message);
      e.target.reset();
    } catch (err) { toast(err.message, true); }
  });
}
