# themis-phone-testers

A copy of [pierridotite/mobile-agent-testers](https://github.com/pierridotite/mobile-agent-testers)
(MIT, from commit aa69f3f), changed to test a **website** instead of an app:

- New workflow input `web_url`. When it is set, nothing is built: each phone opens the
  address in its own browser (Chrome on Android, Safari on iOS), with `qa=phone-<persona>`
  added so the visit is marked as a test.
- `scripts/android/run_agent.sh` and `scripts/ios/run_agent.sh`: the website branch
  (no install; Chrome's first-run screens skipped; the persona's text size, theme and
  location still applied).
- `briefs/themis.md`: what the testers do and never do on TheMIS (no sign-ups, no names
  or e-mail addresses typed, at most one AI question).
- `personas.json`: four TheMIS personas added after the template's twenty
  (`rita`, `dev` on Android; `paula`, `omar` on iOS).
- No results key is committed until `./setup.sh` has been run (the template's own key
  was removed, so a run cannot start before setup).

Run (four phones, at night):

```bash
gh workflow run agent-testers.yml -f web_url=<test copy address> \
  -f android_personas=rita,dev -f ios_personas=paula,omar -f brief=briefs/themis.md
```
