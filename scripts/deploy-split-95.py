"""Context-guarded expense split for expense routing (REVIEW-95 / FUNDING-BLOCK-2026-11-21).

An ordinary expense may be split by the user: the part from the budget is recovered in the chosen
budget months through the existing 'recovery' policy, the rest stays on savings. Only the function
`createExpenseRouting` is replaced, in both Workers (site and app). The live Workers are bundled
(comments removed, `const` printed as `var`), so the function is found by its name and its braces,
and the live version must be the build 91 one: three destinations with savings, no split yet.
Never logs source or credentials.
"""
from pathlib import Path
import importlib.util
import re

spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

HEAD = 'function createExpenseRouting('
CALL = re.compile(r'\b(?:const|let|var)\s+expenseRouting\s*=\s*createExpenseRouting\(')


def routing():
    text = Path('backend/expense-routing/routing.mjs').read_text(encoding='utf-8')
    text = text.replace('export function createExpenseRouting', 'function createExpenseRouting', 1)
    start = text.index(HEAD)
    return text[start:function_end(text, start)]


def function_end(source, start):
    """Index just after the closing brace of the function starting at `start`.
    Skips strings, template literals, comments and regular expression literals."""
    i = source.index('(', start)  # parameter list first (it may hold destructuring braces), then the body
    depth, n = 0, len(source)
    stack = []  # template literal nesting: depth at which a ${ opened
    prev = ''
    while i < n:
        c = source[i]
        if c in '"\'':
            j = i + 1
            while source[j] != c:
                j += 2 if source[j] == '\\' else 1
            i = j + 1; prev = 'v'; continue
        if c == '`':
            j = i + 1
            while True:
                if source[j] == '\\': j += 2; continue
                if source[j] == '`': break
                if source.startswith('${', j):
                    stack.append(depth); depth += 1; j += 2; break
                j += 1
            if source[j] == '`':
                i = j + 1; prev = 'v'; continue
            i = j; prev = '{'; continue
        if source.startswith('//', i):
            i = source.index('\n', i); continue
        if source.startswith('/*', i):
            i = source.index('*/', i) + 2; continue
        if c == '/' and prev in ('', '(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}', ';', 'op'):
            j, in_class = i + 1, False
            while True:
                d = source[j]
                if d == '\\': j += 2; continue
                if d == '[': in_class = True
                elif d == ']': in_class = False
                elif d == '/' and not in_class: break
                j += 1
            j += 1
            while j < n and source[j].isalpha(): j += 1
            i = j; prev = 'v'; continue
        if c in '([':
            depth += 1
        elif c in ')]':
            depth -= 1
        elif c == '{':
            depth += 1
        elif c == '}':
            if stack and depth - 1 == stack[-1]:
                # end of a ${ } inside a template literal: resume the template
                stack.pop(); depth -= 1
                j = i + 1
                while True:
                    if source[j] == '\\': j += 2; continue
                    if source[j] == '`': break
                    if source.startswith('${', j):
                        stack.append(depth); depth += 1; j += 2; break
                    j += 1
                if source[j] == '`':
                    i = j + 1; prev = 'v'; continue
                i = j; prev = '{'; continue
            depth -= 1
            if depth == 0:
                return i + 1
        if not c.isspace():
            if c.isalnum() or c in '_$)]':
                prev = 'v'
                m = re.match(r'[A-Za-z_$][\w$]*', source[i:])
                if m:
                    word = m.group(0)
                    prev = 'op' if word in ('return', 'typeof', 'case', 'in', 'of', 'delete', 'void', 'throw', 'new') else 'v'
                    i += len(word); continue
            else:
                prev = c if c in '(,=:[!&|?{};' else ('op' if c in '+-*%<>~^' else 'v')
        i += 1
    raise RuntimeError('Fine della funzione di routing non trovata; nessuna scrittura.')


def compact(text):
    # Bundlers print true/false as !0/!1 and may switch quote style.
    t = re.sub(r'\s+', '', text).replace('"', "'")
    return re.sub(r'(?<![\w$)\]])!0(?![\w$])', 'true', re.sub(r'(?<![\w$)\]])!1(?![\w$])', 'false', t))


def transform(source):
    if source.count(HEAD) != 1 or len(CALL.findall(source)) != 1:
        print('ROUTING_MARKERS head=%d call=%d' % (source.count(HEAD), len(CALL.findall(source))))
        raise RuntimeError('Contesto routing non riconosciuto; nessuna scrittura.')
    a = source.index(HEAD)
    b = function_end(source, a)
    if CALL.search(source).start() < b:
        raise RuntimeError('Routing non riconosciuto; nessuna scrittura.')
    current, replacement = source[a:b], routing()
    if current == replacement or 'splitDestination' in current:
        if compact(current) != compact(replacement):
            raise RuntimeError('Ripartizione gia presente ma diversa; nessuna scrittura.')
        return source
    live = compact(current)
    # The build 91 routing: savings destination declared, three destinations, plan payments.
    # Known live versions: build 91 (savings destination) or build 90 (budget or plan only; the
    # savings destination was approved on 16/11 but never reached the live Workers).
    v91 = ("savingsDestination:true", "['ordinary','plan','savings'].includes(input.expenseDestination)", "budgetTreatment:kind")
    v90 = ("['ordinary','plan'].includes(input.expenseDestination)", "budgetTreatment:'ordinary'", "version:1,utilityCompetenceVersion")
    common = ("createExpenseRouting({PlanError,balance,command", "'pay',paymentInput")
    found = {n: n in live for n in v91 + v90 + common}
    print('ROUTING_CHECK ' + ' '.join('%s=%d' % (n.split('(')[0].split(':')[0][:24], int(v)) for n, v in found.items()))
    if not (all(found[n] for n in common) and (all(found[n] for n in v91) or all(found[n] for n in v90))):
        raise RuntimeError('Routing live differente dalla versione attesa; nessuna scrittura.')
    if 'splitDestination: true' not in replacement or "input.budgetTreatment === 'recovery'" not in replacement:
        raise RuntimeError('Sorgente routing senza ripartizione; nessuna scrittura.')
    return source[:a] + replacement + source[b:]


if __name__ == '__main__':
    deployment.transform = transform
    deployment.main(label='EXPENSE_SPLIT_95_DEPLOYED_AND_VERIFIED')
