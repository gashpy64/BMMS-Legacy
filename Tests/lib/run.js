'use strict';
/*
  run.js - the browser side of the BMMS tester (step WF3a1).

  Started only by Tests/_runner/Run-Tests.ps1, after it has restored the baseline, synced the
  site copy, checked its connection string and started it on localhost. Usage:

      node lib/run.js --results <folder> [--proof-only] [--pack <name>]...

  What it does
    1. Proves the database: signs in as the fixture's Admin and reads the footer line
       "Database: BMMS_Quality" (the application reads the name from its open connection).
       Anything else stops the run before any pack: exit code 4.
    2. Runs the packs (Tests/packs/<name>/pack.js) in the order given.
    3. Writes <folder>/checks.json and the screenshots. It decides no verdict: Run-Tests.ps1 does.

  Rules built in
    - Only http://localhost is ever requested. A request to any other host is aborted and listed.
    - It signs in only with the fixture accounts of Tests/local/credentials.json and prints no
      password.
    - It writes only inside the results folder.
*/
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const DATABASE = 'BMMS_Quality';
const TESTS = path.resolve(__dirname, '..');
const BASE = String(process.env.QA_BASE_URL || '');
const SITE_DIR = String(process.env.QA_SITE_DIR || '');
const SESSION_MAX_MS = 6 * 60 * 1000; // the site ends a session after 10 minutes without a request

function fail(message) { const e = new Error(message); e.fatal = true; throw e; }

function parseArgs(argv) {
  const out = { results: null, packs: [], proofOnly: false, phase: 'main', checksFile: 'checks.json' };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--results') out.results = argv[++i];
    else if (argv[i] === '--pack') out.packs.push(argv[++i]);
    else if (argv[i] === '--proof-only') out.proofOnly = true;
    else if (argv[i] === '--phase') out.phase = argv[++i];
    else if (argv[i] === '--checks-file') out.checksFile = argv[++i];
    else fail('unknown argument: ' + argv[i]);
  }
  if (!out.results) fail('--results is required');
  // Step WF3a2: the standing proof of the access matrix runs as its own phase, into its own checks file.
  if (!/^(main|planted|planted-full)$/.test(out.phase)) fail('--phase is main, planted or planted-full');
  if (!/^checks(-[a-z]+)?\.json$/.test(out.checksFile)) fail('--checks-file is checks.json or checks-<name>.json');
  for (const p of out.packs) if (!/^[a-z0-9][a-z0-9-]*$/.test(p)) fail('pack names are lower-case letters, digits and hyphens: ' + p);
  return out;
}

function slug(text) { return String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60); }

class Tester {
  constructor(browser, creds, resultsDir, phase) {
    this.browser = browser;
    this.creds = creds;
    this.resultsDir = resultsDir;
    this.shotDir = path.join(resultsDir, 'screenshots');
    this.checks = [];
    this.blocked = [];
    this.sessions = new Map();
    this.pack = '';
    this.phase = phase || 'main';
    this.shotPrefix = this.phase === 'main' ? '' : 'p';
    this.siteDir = path.resolve(SITE_DIR);
    this.repo = path.resolve(TESTS, '..');
    this.accessLog = path.join(SITE_DIR, 'App_Data', 'PageAccessLog.txt');
    fs.mkdirSync(this.shotDir, { recursive: true });
  }

  get roles() { return Object.keys(this.creds.accounts); }

  async newContext() {
    const context = await this.browser.newContext({ viewport: { width: 1366, height: 768 }, locale: 'en-GB' });
    context.setDefaultTimeout(30000);
    context.setDefaultNavigationTimeout(60000);
    await context.route('**/*', (route) => {
      let host = '';
      try { host = new URL(route.request().url()).hostname; } catch (e) { host = '?'; }
      if (host === 'localhost' || host === '127.0.0.1') return route.continue();
      this.blocked.push({ pack: this.pack, url: route.request().url().slice(0, 200) });
      return route.abort();
    });
    return context;
  }

  // Signs in on the real sign-in page. Refuses the "change password at first sign-in" page:
  // the fixture accounts must not land there.
  async signIn(role) {
    const account = this.creds.accounts[role];
    if (!account) fail('no test account for role key "' + role + '"');
    const context = await this.newContext();
    const page = await context.newPage();
    await page.goto(BASE + '/Default.aspx', { waitUntil: 'domcontentloaded' });
    await page.locator('[id$="txtLoginName"]').fill(account.login);
    await page.locator('[id$="txtPassword"]').fill(account.password);
    // The page limits both boxes (12 characters); a longer value is cut off as a user's typing would be.
    const typedLogin = await page.locator('[id$="txtLoginName"]').inputValue();
    const typedLength = (await page.locator('[id$="txtPassword"]').inputValue()).length;
    if (typedLogin !== account.login || typedLength !== account.password.length) {
      await context.close();
      fail('the sign-in page did not take the whole User ID or Password of "' + role + '" (longer than the page allows)');
    }
    await Promise.all([
      page.waitForURL((u) => !/\/default\.aspx$/i.test(new URL(u).pathname), { timeout: 60000 }).catch(() => null),
      page.locator('[id$="btnLogin"]').click(),
    ]);
    await page.waitForLoadState('domcontentloaded');
    const where = new URL(page.url()).pathname;
    return { context, page, where, signedInAt: Date.now() };
  }

  // A signed-in page for the role, kept for the run and renewed before the site would end it.
  async session(role) {
    let s = this.sessions.get(role);
    if (s && Date.now() - s.signedInAt > SESSION_MAX_MS) { await s.context.close(); s = null; }
    if (!s) {
      s = await this.signIn(role);
      if (!/\/dashboard\/dashboard\.aspx$/i.test(s.where)) {
        const text = (await s.page.locator('body').innerText().catch(() => '')).replace(/\s+/g, ' ').slice(0, 160);
        await s.context.close();
        fail('sign-in as "' + role + '" did not reach the Dashboard (landed on ' + s.where + '): ' + text);
      }
      this.sessions.set(role, s);
    }
    return s.page;
  }

  // After Logout.aspx the session is over: the next session(role) signs in again.
  async endSession(role) {
    const s = this.sessions.get(role);
    this.sessions.delete(role);
    if (s) await s.context.close().catch(() => null);
  }

  async anonymousPage() {
    const context = await this.newContext();
    return { context, page: await context.newPage() };
  }

  // Opens an address of the site and says in one word what came back.
  //   opens     HTTP 200 on the page asked for
  //   denied    HTTP 403 with the "Access denied" page
  //   notfound  HTTP 404 with the "Page not found" page
  //   signin    sent to the sign-in page
  //   error     the application's error page
  async visit(page, address) {
    const url = BASE + '/' + String(address).replace(/^\/+/, '');
    let response = null;
    try { response = await page.goto(url, { waitUntil: 'domcontentloaded' }); }
    catch (e) { return { kind: 'no-answer', status: 0, path: '', note: String(e.message).split('\n')[0].slice(0, 160) }; }
    const status = response ? response.status() : 0;
    const finalPath = new URL(page.url()).pathname;
    const askedPath = new URL(url).pathname;
    const body = (await page.locator('body').innerText().catch(() => '')).replace(/\s+/g, ' ');
    let kind;
    if (/\/error\/errorpage\.aspx$/i.test(finalPath) && !/\/error\/errorpage\.aspx$/i.test(askedPath)) kind = 'error';
    else if (/\/default\.aspx$/i.test(finalPath) && !/\/default\.aspx$/i.test(askedPath)) kind = 'signin';
    else if (status === 403 && /Access denied/i.test(body)) kind = 'denied';
    // The application's "Page not found" page, or IIS's own 404 page for a missing static file (step WF3a2)
    else if (status === 404 && /Page not found|HTTP Error 404|cannot be found/i.test(body)) kind = 'notfound';
    else if (status === 200) kind = 'opens';
    else kind = 'http-' + status;
    return { kind, status, path: finalPath, note: body.slice(0, 120) };
  }

  logMark() { try { return fs.statSync(this.accessLog).size; } catch (e) { return 0; } }
  logSince(mark) {
    try {
      const size = fs.statSync(this.accessLog).size;
      if (size <= mark) return [];
      const fd = fs.openSync(this.accessLog, 'r');
      const buffer = Buffer.alloc(size - mark);
      fs.readSync(fd, buffer, 0, size - mark, mark);
      fs.closeSync(fd);
      return buffer.toString('utf8').split(/\r?\n/).filter((l) => l.trim() !== '');
    } catch (e) { return []; }
  }

  async shot(page, name) {
    const file = this.shotPrefix + String(this.checks.length + 1).padStart(4, '0') + '-' + slug(name) + '.png';
    try { await page.screenshot({ path: path.join(this.shotDir, file), fullPage: false }); return 'screenshots/' + file; }
    catch (e) { return ''; }
  }

  record(check) {
    const c = Object.assign({ id: this.checks.length + 1, pack: this.pack, planted: false, screenshot: '', accessLog: [], detail: '' }, check);
    c.pass = !!c.pass;
    this.checks.push(c);
    return c;
  }

  // One row of an expected-results table: a role opens an address; what came back is compared
  // with what was expected. "planted" marks a deliberately wrong expectation (the self-test).
  async check(opts) {
    const role = opts.role;
    let page, context = null;
    if (role === 'anonymous') ({ context, page } = await this.anonymousPage());
    else page = await this.session(role);
    const mark = this.logMark();
    const seen = await this.visit(page, opts.address);
    const pass = seen.kind === opts.expected;
    const lines = this.logSince(mark);
    let screenshot = '';
    if (!pass || opts.shot) screenshot = await this.shot(page, role + '-' + opts.address);
    if (context) await context.close();
    return this.record({
      title: opts.title || (role + ' opens ' + opts.address),
      role, address: opts.address, expected: opts.expected, seen: seen.kind,
      detail: 'HTTP ' + seen.status + (seen.path ? ', ended on ' + seen.path : '') + (seen.kind.startsWith('http-') || seen.kind === 'no-answer' ? ' - ' + seen.note : ''),
      pass, planted: !!opts.planted, screenshot, accessLog: lines,
    });
  }

  async close() { for (const s of this.sessions.values()) await s.context.close().catch(() => null); this.sessions.clear(); }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const resultsDir = path.resolve(args.results);
  if (!resultsDir.toLowerCase().startsWith(path.join(TESTS, '_results').toLowerCase() + path.sep)) fail('the results folder must be inside Tests/_results');
  if (!/^http:\/\/localhost:\d{2,5}$/.test(BASE)) fail('QA_BASE_URL must be http://localhost:<port>');
  if (!SITE_DIR || path.resolve(SITE_DIR).toLowerCase() !== path.join(TESTS, '_site').toLowerCase()) fail('QA_SITE_DIR must be Tests/_site');
  fs.mkdirSync(resultsDir, { recursive: true });
  const creds = JSON.parse(fs.readFileSync(path.join(TESTS, 'local', 'credentials.json'), 'utf8').replace(/^﻿/, ''));

  const out = { database: DATABASE, baseUrl: BASE, startedAt: new Date().toISOString(), finishedAt: null, proof: null, packs: [], checks: [], blockedRequests: [], fatal: null };
  out.phase = args.phase;
  const write = () => fs.writeFileSync(path.join(resultsDir, args.checksFile), JSON.stringify(out, null, 2));
  let browser = null, tester = null, code = 0;
  try {
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    tester = new Tester(browser, creds, resultsDir, args.phase);
    out.browser = 'Chrome ' + browser.version();

    // 1. The database proof, before anything else is opened.
    const s = await tester.signIn('admin');
    const footerDb = (await s.page.locator('[id$="lblFooterDatabase"]').innerText().catch(() => '')).trim();
    const footer = (await s.page.locator('[id$="lblFooter"]').first().innerText().catch(() => '')).trim();
    const who = (await s.page.locator('.wb-user-name').first().innerText().catch(() => '')).trim();
    out.proof = { landedOn: s.where, footerDatabase: footerDb, footer: footer.slice(0, 120), signedInAs: who };
    if (footerDb !== 'Database: ' + DATABASE) {
      await s.page.screenshot({ path: path.join(resultsDir, 'database-proof-failed.png') }).catch(() => null);
      await s.context.close();
      fail('the site under test does not show "Database: ' + DATABASE + '" in its footer (it shows "' + footerDb + '", landed on ' + s.where + '). No pack was run.');
    }
    tester.sessions.set('admin', s);

    // 2. The packs.
    if (!args.proofOnly) {
      for (const name of args.packs) {
        const file = path.join(TESTS, 'packs', name, 'pack.js');
        if (!fs.existsSync(file)) fail('pack not found: ' + name);
        const pack = require(file);
        tester.pack = name;
        const before = tester.checks.length;
        const started = Date.now();
        let error = null;
        try { await pack.run(tester); }
        catch (e) { if (e.fatal) throw e; error = String(e.message).split('\n')[0].slice(0, 300); }
        out.packs.push({ name, title: pack.title || name, checks: tester.checks.length - before, seconds: Math.round((Date.now() - started) / 100) / 10, error });
      }
    }
  } catch (e) {
    out.fatal = String(e.message).split('\n')[0].slice(0, 500);
    code = 4;
  } finally {
    if (tester) { out.checks = tester.checks; out.blockedRequests = tester.blocked; await tester.close(); }
    if (browser) await browser.close().catch(() => null);
    out.finishedAt = new Date().toISOString();
    write();
  }
  process.exit(code);
}

main().catch((e) => { console.error('run.js failed: ' + String(e.message).split('\n')[0]); process.exit(4); });
