# rule.forbid.adhoc-shell

## 🛑 .the rule, in one line

# **AN ABSENT SKILL IS THE DEFECT TO FIX. IT IS NEVER A LICENCE TO GO ADHOC.**

when you reach for a capability and no skill wraps it, **write the skill**. do not run the
raw command once and move on.

## .why this rule exists beside the other two

two rules already cover the reach:

| rule | what it governs |
|---|---|
| `rule.require.reach-for-the-skill-before-adhoc-shell` | a READ, where a skill already answers |
| `rule.require.wrap-cli-in-skills` | a raw CLI call, where a skill could wrap it |

neither states the decision at the moment that matters most: **the skill is absent, and I want
the capability now.** that moment is where both rules leak, because their answer reads as
*"reach for the skill"* — and there is none to reach for.

⇒ so this rule names what an absence MEANS:

> an absent skill is a fact about the **inventory**, and the inventory is mine to change. it is
> not a fact about what the work requires.

## .measured — 2026-09-03, the `term.*` family

a kitty window was owed against a remote duct. i typed a raw `kitty --detach -e ssh …`. the
human's read: *"dont you have rhx skills for this?"* → *"entool"* → *"never adhoc"* → and the
line that settles it:

> **"if you cant entool it, why do you do it"**

the inventory at that hour:

| family | skills |
|---|---|
| `duct.*` | 8 |
| `term.*` | **0** |

same repo, same session, two peer families — one wrapped, one bare. so the absence carried no
verdict about the capability. it recorded which family somebody had reached first.

⇒ and the repair cost **one** `term.operations.sh` plus five thin dispatchers. the price of the
rule sits far under the price of the habit.

## 🛑 .the escape hatch this retires

`rule.require.reach-for-the-skill-before-adhoc-shell` used to close with:

> *none does, and it genuinely will not recur → ad-hoc is fine, and say why*

that clause is struck. it earns a note on why, rather than a silent delete:

- **"it will not recur" is unfalsifiable at the moment of use.** every one-off feels like one
  while you type it. i believed it about `kitty --detach`, then needed the same window three
  more times that hour.
- **its justification never varies**, which is `rule.forbid.exemption-as-habit`'s exact tell:
  an exemption whose trigger is always the same names a permanent condition, and a permanent
  condition is an absent feature.

## .what remains legitimate

this rule forbids the raw call as a **substitute for a skill**. it does not forbid the shell:

| shape | verdict |
|---|---|
| `rhx <skill>` | ✔ always |
| a raw call **inside** a skill you author | ✔ that is the wrapper at work |
| a raw call to DISCOVER a tool's flags, before you wrap it | ✔ bounded, and it ends in a skill |
| a raw call typed as the answer, with no skill to follow | ✋ **blocker** |

the discriminator is **what you leave behind.** an exploration that ends in a committed skill
is the rule at work. one that ends in a remembered incantation is the rule broken.

## .the test

> **i am about to type a raw command. what will hold this capability tomorrow?**

- a skill i am about to write → correct
- my memory of this line → **stop, and write the skill**

## .enforcement

- a raw command run as the answer to a capability that has no skill, with no skill authored =
  **blocker**
- *"no skill exists"* cited as the reason a raw call was correct = **blocker**; that is the
  premise this rule inverts
- a HALT recorded because a family holds no skills = **blocker**; the family is yours to fill
- an exploration of a tool's flags that ends with no skill committed = **blocker**

## .see also

- `rule.require.reach-for-the-skill-before-adhoc-shell` — the read-path reach; this rule holds
  the moment its table has no row
- `rule.require.wrap-cli-in-skills` — what the skill you write must carry
- `rule.require.name-a-skill-by-who-invokes-it` — how to name it once written
- `howto.wrap-a-shell-alias-in-an-rhx-skill` — the procedure, with the `<family>.operations.sh`
  pattern the `term.*` family follows
- `rule.forbid.exemption-as-habit` — why the struck clause had to go
- `rule.require.solve-at-cause` — an absent tool is the cause; the raw call treats the symptom
