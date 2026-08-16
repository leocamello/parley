## What this changes

<!-- One paragraph: the behavior before, the behavior after, and which
     design document or decision covers it (docs/design/, architecture.md §8). -->

## How it is proved

<!-- Parley is law-tested: name the laws or acceptance scenarios that
     cover the change, and say what `./scripts/verify-sprint.sh` answers
     on your branch. A behavior change without a law over it is the one
     shape this repository does not merge. -->

## Checklist

- [ ] `./scripts/verify-sprint.sh` is green locally (both seeds if you can: default and `--seed 42`)
- [ ] New behavior carries a law that fails without the change
- [ ] Diagnosis wordings follow the settled `'<path>: cause - remedy'` grammar and blame the right party
- [ ] No hard-ban violations (no third-party evaluation, no kernel shadowing, no third-party libraries)
- [ ] Docs updated where a stated behavior moved (`docs/design/`, README)
