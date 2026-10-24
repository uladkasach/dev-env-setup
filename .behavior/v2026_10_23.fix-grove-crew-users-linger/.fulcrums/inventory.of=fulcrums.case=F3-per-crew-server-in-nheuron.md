# F3 — one server per crew is built in nheuron, dispatched from here

- fork: implement the per-crew server in this repo vs dispatch it to nheuron
- taken: dispatch — the crew verbs choose the socket (nheuron ductwork's `DUCTWORK_TMUX_SOCKET`
  seam, `define.work-primitive-hierarchy.md:172`); this repo's ductwork serves the human's own
  ducts and is not what crews call. provision has no lever to pick a client's socket
- this repo's share: every server is the pinned build, the conf loads per server, configure
  verify walks every live socket (extant), a crash leaves a core
- rework: clean — the dispatch is a radio task; no code here hardens against it
- confidence 70%, low because the instruction says the provision fix should "carry" one server
  per crew, which may mean it expects code here
- where: radio task into uladkasach/nheuron
- re-asked i004 by r10 (enroll-impl-behavior-intent, blocker.1): the wish title promises one
  crash ends one crew, and here every crew still shares `default`; case 6 has no test here. the
  test of case 6 is owed where the split lands (nheuron#44). this repo's share: the PR now says
  what it does not deliver (draft `.temp/pr170.body.md`). a per-plan 🌙 "N crews share one
  server" was weighed and declined: it would fire on every grove until nheuron#44 lands, a
  permanent moon a reader learns to skip
