# DMN TCK

The test cases of the [DMN TCK](https://github.com/dmn-tck/tck) (compliance
levels 2 and 3), run with FEEL:

```bash
bundle exec rake tck                     # all the test cases (also part of `rake`)
bundle exec rake tck FILTER=0072-feel-in # the test cases of some folders
bundle exec rake tck:accept              # accept the current failures as expected
bundle exec rake tck:update              # update the test cases (REVISION=commit)
```

`cases/` holds the models (`.dmn`) and test cases (`*-test-*.xml`) of the TCK
at the revision in `cases/REVISION` (Apache License 2.0, `cases/LICENSE`).

The runner (`runner.rb`) translates the boxed expressions of the models into
FEEL (contexts, invocations, lists, relations, function definitions, the
conditionals, filters and iterations of DMN 1.5, decision tables with all the
hit policies) and evaluates them with FEEL. BKMs become FEEL functions. As a
DMN engine does, it escapes the names of the model that contain spaces (e.g.
`Full Name`) with backticks. Numbers are compared as the TCK runners do: with
a difference below 0.00000001.

`expected_failures.txt` lists the test cases that are expected to fail, with
the reason. `rake tck` fails if another test case fails (a regression) or if a
listed one passes (then remove it from the list with `rake tck:accept`). The
results of the last run are in `tmp/tck_results.tsv`.

Not supported by the runner: decision services, imports, Java functions,
and the typing of DMN (coercion to the type of a decision or input).
