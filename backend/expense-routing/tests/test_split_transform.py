"""The split deployment must turn the build 91 Worker into the Worker the tests ran against,
also when the live Worker is bundled (no comments, `var` instead of `const`, double quotes)."""
from pathlib import Path
import importlib.util
import re
import subprocess


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), Path('scripts') / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


split = load('deploy-split-95')
current = Path('manual/build-75/worker.js').read_text(encoding='utf-8')
new_fn = split.routing()
assert new_fn.startswith('function createExpenseRouting(') and new_fn.rstrip().endswith('}')
old_source = subprocess.check_output(['git', 'show', '2f2fd2a:backend/expense-routing/routing.mjs'], text=True, encoding='utf-8')
old_fn = old_source[old_source.index('function createExpenseRouting('):]
old_fn = old_fn[:split.function_end(old_fn, 0)]
assert current.count(new_fn) == 1, 'build-75 must be generated from the current routing source first'
previous = current.replace(new_fn, old_fn, 1)
assert previous != current
assert split.transform(previous) == current
assert split.transform(current) == current

# A bundled live Worker: comments gone, `var`, double-quoted strings inside the routing function.
bundled_fn = re.sub(r'^\s*//.*\n', '', old_fn, flags=re.M)
bundled_fn = bundled_fn.replace('savingsDestination: true', 'savingsDestination: !0').replace("['ordinary','plan','savings']", '["ordinary", "plan", "savings"]').replace("command(state,'pay',", 'command(state, "pay", ')
bundled = previous.replace(old_fn, bundled_fn, 1)
bundled = re.sub(r'\bconst expenseRouting = createExpenseRouting\(', 'var expenseRouting = createExpenseRouting(', bundled, count=1)
result = split.transform(bundled)
assert result.count(new_fn) == 1 and bundled_fn not in result
assert split.transform(result) == result

# The live Workers still run the build 90 routing (no savings destination): it is upgraded too.
v90_source = subprocess.check_output(['git', 'show', '04ad889:backend/expense-routing/routing.mjs'], text=True, encoding='utf-8')
v90_fn = v90_source[v90_source.index('function createExpenseRouting('):]
v90_fn = v90_fn[:split.function_end(v90_fn, 0)]
v90 = current.replace(new_fn, v90_fn, 1)
assert v90 != current and split.transform(v90) == current

for tampered in (previous.replace("savingsDestination: true", "savingsDestination: false", 1),
                 previous.replace('function createExpenseRouting(', 'function otherRouting(', 1)):
    try:
        split.transform(tampered)
    except RuntimeError:
        pass
    else:
        raise AssertionError('A different live routing must be refused')
# The first build 95 routing (live since f9155ce) is upgraded to the current one.
v95_first = current.replace(new_fn, split.routing_at(split.V95_COMMIT), 1)
assert v95_first != current and split.transform(v95_first) == current
v95_plan = current.replace(new_fn, split.routing_at('7e7a5b3'), 1)
assert v95_plan != current and split.transform(v95_plan) == current
print('OK')
