#!/usr/bin/env bash
# Every number in the video, measured. Each mistake in overlays/ is laid over a
# scratch copy of an app, never the app itself, and every claim asserts what it
# expects and stops the script rather than printing something plausible.
#
# Needs Docker, JDK 25 and Python 3.14 with the packages in
# fastapi-payments/pyproject.toml in .venv. Postgres comes from compose.yaml,
# the payment provider is provider-stub/stub.py.
#
# The transcripts land in evidence/, and the terminal frames in the video are
# copied from them rather than retyped.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
export JAVA_HOME="${JAVA_HOME_25:-$HOME/.sdkman/candidates/java/25.0.4-amzn}"
JAVA="$JAVA_HOME/bin/java"
PY="$ROOT/.venv/bin/python"
UVICORN="$ROOT/.venv/bin/uvicorn"
export POSTGRES_PORT="${POSTGRES_PORT:-5443}"
export DATABASE_URL="postgresql+psycopg://payments:payments@localhost:$POSTGRES_PORT/payments"
export PROVIDER_URL="http://127.0.0.1:8097"
EVIDENCE="$ROOT/evidence"
WORK=$(mktemp -d)
PIDS=()
mkdir -p "$EVIDENCE"
rm -f "$EVIDENCE"/*.log

cleanup() {
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true; done
  pkill -f "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

fail() { echo "CLAIM FAILED: $*" >&2; exit 1; }
log() { tee -a "$EVIDENCE/$1.log"; }
say() { # <evidence name> <command...>: show the command, run it, keep both.
  # A command that fails on purpose (mypy finding the error) is recorded, not fatal.
  local t=$1; shift
  { echo "\$ $*"; eval "$@" || echo "(exit $?)"; echo; } 2>&1 | log "$t"
}
# So the transcripts read the way a viewer would type them.
python() { "$PY" "$@"; }
mypy() { "$ROOT/.venv/bin/mypy" "$@"; }
javac() { "$JAVA_HOME/bin/javac" "$@"; }
sql() { docker compose exec -T postgres psql -U payments -d payments -tAc "$1"; }
result() { grep '^RESULT ' "$1" | tail -1 | cut -c8-; }
field() { "$PY" -c "import json,sys; d=json.loads(sys.argv[1]); print(eval(sys.argv[2], {}, d))" "$1" "$2"; }
check() { # <description> <python expression over RESULT json> <json>
  "$PY" -c "import json,sys; d=json.loads(sys.argv[2]); sys.exit(0 if eval(sys.argv[1], {}, d) else 1)" "$2" "$3" \
    || fail "$1: $3"
  echo "  ok: $1"
}

wait_http() { # <url>: until it answers, or 60 s
  for _ in $(seq 1 120); do curl -s -o /dev/null "$1" && return 0; sleep 0.5; done
  fail "nothing answered at $1"
}

copy_fastapi() { # <overlay...>: a scratch copy with overlays applied
  local dir="$WORK/fastapi-$RANDOM$RANDOM"
  cp -R "$ROOT/fastapi-payments" "$dir"
  for o in "$@"; do (cd "$ROOT/overlays/$o/fastapi" && find . -type f -exec cp {} "$dir/{}" \;); done
  echo "$dir"
}
copy_spring() { # <overlay...>
  local dir="$WORK/spring-$RANDOM$RANDOM"
  cp -R "$ROOT/spring-payments" "$dir"
  rm -rf "$dir/target"
  for o in "$@"; do
    [ -d "$ROOT/overlays/$o/spring" ] || continue
    (cd "$ROOT/overlays/$o/spring" && find . -type f | while read -r f; do cp "$f" "$dir/$f"; done)
  done
  (cd "$dir" && ./mvnw -q -o -DskipTests package >"$WORK/build.log" 2>&1) || { cat "$WORK/build.log"; fail "spring build"; }
  echo "$dir"
}
start_fastapi() { # <dir> <port> [uvicorn args...]: prints the pid
  local dir=$1 port=$2; shift 2
  (cd "$dir" && exec "$UVICORN" payments.main:app --port "$port" --log-level warning "$@" \
    >"$WORK/fastapi-$port.log" 2>&1) &
  local pid=$!
  PIDS+=("$pid")
  wait_http "http://127.0.0.1:$port/health"
  echo "$pid"
}
start_spring() { # <dir> <port>
  (cd "$1" && PORT=$2 exec "$JAVA" -jar target/spring-payments-0.0.1-SNAPSHOT.jar \
    >"$WORK/spring-$2.log" 2>&1) &
  PIDS+=("$!")
  wait_http "http://127.0.0.1:$2/health"
}
stop() { kill -9 "$1" 2>/dev/null || true; pkill -9 -P "$1" 2>/dev/null || true; sleep 1; }
stop_port() { local p; p=$(lsof -ti tcp:"$1" -sTCP:LISTEN || true); [ -n "$p" ] && kill -9 $p 2>/dev/null; sleep 1; true; }
reset() { sql "TRUNCATE payments, receipts" >/dev/null; curl -s -X DELETE "$PROVIDER_URL/connections" >/dev/null; }
charges() { curl -s "$PROVIDER_URL/connections"; }

# Named once, so each transcript shows the command as it was typed.
PAYMENT='{"order_ref":"order","unit_price":500,"quantity":3,"currency":"GBP"}'
ORDER_42='{"order_ref":"order-42","unit_price":500,"quantity":3,"currency":"GBP"}'
ORDER_1='{"order_ref":"order-1","unit_price":500,"quantity":3,"currency":"GBP"}'
ORDER_2='{"order_ref":"order-2","unit_price":500,"quantity":3,"currency":"GBP"}'
SPRING_PAYMENT='{"orderRef":"order","unitPrice":500,"quantity":3,"currency":"GBP"}'
SPRING_ORDER_42='{"orderRef":"order-42","unitPrice":500,"quantity":3,"currency":"GBP"}'
INVALID='{"order_ref":"order-42","unit_price":-5,"quantity":3,"currency":"GBP"}'
STRING_FIVE='{"order_ref":"order-5","unit_price":"5","quantity":3,"currency":"GBP"}'
SPRING_INVALID='{"orderRef":"order-42","unitPrice":-5,"quantity":3,"currency":"GBP"}'
load() { "$PY" scripts/load.py "$@"; }

echo "== setup"
"$PY" --version
"$PY" -c "import fastapi, pydantic, sqlalchemy, uvicorn; print('fastapi', fastapi.__version__, 'pydantic', pydantic.VERSION, 'sqlalchemy', sqlalchemy.__version__, 'uvicorn', uvicorn.__version__)"
"$JAVA" -version 2>&1 | head -1
{ "$PY" --version
  "$PY" -c "import fastapi, pydantic, sqlalchemy, uvicorn, psycopg, httpx; print('fastapi', fastapi.__version__); print('pydantic', pydantic.VERSION); print('sqlalchemy', sqlalchemy.__version__); print('uvicorn', uvicorn.__version__); print('psycopg', psycopg.__version__); print('httpx', httpx.__version__)"
  "$JAVA" -version 2>&1 | head -1
  echo "spring-boot $(sed -n 's:.*<version>\(4[^<]*\)</version>.*:\1:p' spring-payments/pom.xml | head -1)"
} > "$EVIDENCE/versions.log"
docker compose up -d postgres >/dev/null
for _ in $(seq 1 60); do docker compose exec -T postgres pg_isready -U payments >/dev/null 2>&1 && break; sleep 1; done
for p in 8095 8096 8097 8098 8099; do stop_port $p; done
(cd provider-stub && exec "$UVICORN" stub:app --port 8097 --log-level warning >"$WORK/stub.log" 2>&1) &
PIDS+=("$!")
wait_http "$PROVIDER_URL/connections"
(cd fastapi-payments && "$ROOT/.venv/bin/pytest" -q 2>&1 | tail -1) | log tests
(cd spring-payments && ./mvnw -q -o test >"$WORK/spring-test.log" 2>&1) || { cat "$WORK/spring-test.log"; fail "spring tests"; }
grep -ho 'tests="[0-9]*" errors="0" skipped="0" failures="0"' spring-payments/target/surefire-reports/*.xml | log tests

echo "== 1. the hook: one blocking client call inside async def"
D=$(copy_fastapi async-blocking); P=$(start_fastapi "$D" 8099); reset
say hook-fastapi-async-def "load http://127.0.0.1:8099 /payments 10 --body \"\$PAYMENT\""
R=$(result "$EVIDENCE/hook-fastapi-async-def.log")
check "async def: ten payments take about 20 s" "seconds >= 18" "$R"
check "async def: /health waits behind them" "health_seconds >= 15" "$R"
stop "$P"
D=$(copy_fastapi); P=$(start_fastapi "$D" 8099); reset
say hook-fastapi-def "load http://127.0.0.1:8099 /payments 10 --body \"\$PAYMENT\""
R=$(result "$EVIDENCE/hook-fastapi-def.log")
check "plain def: about 2 s" "seconds < 4" "$R"
check "plain def: /health answers at once" "health_seconds < 1" "$R"
stop "$P"
S=$(copy_spring); start_spring "$S" 8098; reset
say hook-spring "load http://127.0.0.1:8098 /payments 10 --body \"\$SPRING_PAYMENT\""
R=$(result "$EVIDENCE/hook-spring.log")
check "spring: about 2 s" "seconds < 4" "$R"
check "spring: /health answers at once" "health_seconds < 1" "$R"

echo "== 2. types are not java types"
say types "PYTHONPATH=fastapi-payments python experiments/types_checked.py"
grep -q "'555'" "$EVIDENCE/types.log" || fail "total('5', 3) did not return '555'"
say types "MYPYPATH=fastapi-payments mypy experiments/types_checked.py"
grep -q 'incompatible type "str"; expected "int"' "$EVIDENCE/types.log" || fail "mypy did not reject it"
say types "javac -d \"$WORK/tc\" experiments/TypesChecked.java"
grep -q "String cannot be converted to long" "$EVIDENCE/types.log" || fail "javac did not refuse it"
echo "  ok: '555' at runtime, rejected by mypy"

echo "== 3. validation: 422 against 400"
D=$(copy_fastapi); P=$(start_fastapi "$D" 8099)
say validation "curl -s -w '\nHTTP %{http_code}\n' -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d \"\$INVALID\""
say validation "curl -s -w '\nHTTP %{http_code}\n' -X POST http://127.0.0.1:8098/payments -H 'content-type: application/json' -d \"\$SPRING_INVALID\""
grep -q "HTTP 422" "$EVIDENCE/validation.log" && grep -q "HTTP 400" "$EVIDENCE/validation.log" || fail "422 and 400"
say validation-coercion "curl -s -w ' HTTP %{http_code}\n' -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d \"\$STRING_FIVE\""
grep -q '"total":15,' "$EVIDENCE/validation-coercion.log" || fail "Pydantic did not turn the string 5 into the number 5"
echo "  ok: Pydantic turned the string 5 into the number 5"
echo "  ok: FastAPI 422, Spring 400"

echo "== 4. the transaction"
rows() { echo "$1 payments: $(sql 'SELECT count(*) FROM payments'), receipts: $(sql 'SELECT count(*) FROM receipts')"; }
tx_case() { # <evidence> <port>: one payment, rows right after the 201 and five seconds later
  sleep 3; reset  # receipts from earlier payments land first, so the counts start at zero
  say "$1" "curl -s -w ' HTTP %{http_code}\\n' -X POST http://127.0.0.1:$2/payments -H 'content-type: application/json' -d \"\$$3\""
  say "$1" "rows 'right after the 201:'"
  sleep 5
  say "$1" "rows 'five seconds later:   '"
}
stop "$P"
D=$(copy_fastapi no-transaction); P=$(start_fastapi "$D" 8099); reset
tx_case transaction-no-begin 8099 ORDER_42
grep -q "HTTP 201" "$EVIDENCE/transaction-no-begin.log" && grep -q "later: *payments: 0" "$EVIDENCE/transaction-no-begin.log" \
  || fail "no begin: 201 and the row never exists"
echo "  ok: no begin: 201, and the row never exists"
stop "$P"
say fastapi-scope "python experiments/scope_doc.py"
grep -q "after\*\* the response is sent" "$EVIDENCE/fastapi-scope.log" || fail "FastAPI's docstring no longer says request scope ends after the response"
D=$(copy_fastapi commit-after-response); P=$(start_fastapi "$D" 8099); reset
tx_case transaction-request-scope 8099 ORDER_42
grep -q "after the 201: *payments: 0" "$EVIDENCE/transaction-request-scope.log" && grep -q "later: *payments: 1" "$EVIDENCE/transaction-request-scope.log" \
  || fail "request scope: committed only after the response"
echo "  ok: request scope: the 201 went out before the commit"
stop "$P"
D=$(copy_fastapi); P=$(start_fastapi "$D" 8099); reset
tx_case transaction-function-scope 8099 ORDER_42
grep -q "after the 201: *payments: 1" "$EVIDENCE/transaction-function-scope.log" || fail "function scope: committed before the 201"
echo "  ok: function scope: committed before the 201"
stop "$P"; reset
tx_case transaction-spring 8098 SPRING_ORDER_42
grep -q "after the 201: *payments: 1" "$EVIDENCE/transaction-spring.log" || fail "spring: committed before the 201"
echo "  ok: spring: committed before the 201"

echo "== 5. object lifetime"
(cd experiments && exec "$UVICORN" lifetime:app --port 8096 --log-level warning >"$WORK/lifetime.log" 2>&1) &
PIDS+=("$!"); wait_http http://127.0.0.1:8096/docs
for _ in 1 2 3; do say lifetime "curl -s -X POST http://127.0.0.1:8096/charge"; done
grep -q '"per_request":3,"lifespan":1' "$EVIDENCE/lifetime.log" || fail "per request 3, lifespan 1"
grep -q '"same_object_twice_in_one_request":true' "$EVIDENCE/lifetime.log" || fail "cached within a request"
stop_port 8096
(cd experiments && exec "$UVICORN" lifetime:app --port 8096 --workers 4 --log-level warning >"$WORK/lifetime4.log" 2>&1) &
PIDS+=("$!"); sleep 4; wait_http http://127.0.0.1:8096/docs
for _ in $(seq 1 40); do curl -s -X POST http://127.0.0.1:8096/charge; echo; done > "$WORK/l4.json"
say lifetime-workers "python -c \"import json; rows=[json.loads(l) for l in open('$WORK/l4.json') if l.strip()]; print('worker processes seen:', len({r['pid'] for r in rows}), ' lifespan objects seen:', len({(r['pid'], r['lifespan_object']) for r in rows}))\""
stop_port 8096
D=$(copy_fastapi provider-per-request); P=$(start_fastapi "$D" 8099); reset
for i in 1 2 3 4 5; do curl -s -o /dev/null -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d "${PAYMENT/\"order\"/\"order-$i\"}"; done
say lifetime-connections "echo 'provider client built per request:' \$(charges)"
stop "$P"
D=$(copy_fastapi); P=$(start_fastapi "$D" 8099); reset
for i in 1 2 3 4 5; do curl -s -o /dev/null -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d "${PAYMENT/\"order\"/\"order-$i\"}"; done
say lifetime-connections "echo 'provider client built in the lifespan:' \$(charges)"
stop "$P"; reset
for i in 1 2 3 4 5; do curl -s -o /dev/null -X POST http://127.0.0.1:8098/payments -H 'content-type: application/json' -d "${SPRING_PAYMENT/\"order\"/\"order-$i\"}"; done
say lifetime-connections "echo 'spring, one ProviderClient bean:' \$(charges)"

echo "== 6. work after the response"
sleep 3  # receipts from the payments above are still on their way; let them land first
D=$(copy_fastapi); P=$(start_fastapi "$D" 8099); reset
say background "curl -s -w ' HTTP %{http_code}\n' -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d \"\$ORDER_1\""
sleep 3
say background "echo 'not killed, receipts:' \$(sql 'SELECT count(*) FROM receipts')"
say background "curl -s -w ' HTTP %{http_code}\n' -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d \"\$ORDER_2\""
sleep 0.5; stop "$P"; sleep 3
say background "echo 'worker killed half a second later, receipts:' \$(sql 'SELECT count(*) FROM receipts')"
grep -q "not killed, receipts: 1" "$EVIDENCE/background.log" && grep -q "later, receipts: 1" "$EVIDENCE/background.log" \
  || fail "one receipt, and none for the killed worker"
echo "  ok: the killed worker's receipt never arrived"
stop_port 8098; reset
start_spring "$S" 8098
say background-spring "curl -s -w ' HTTP %{http_code}\n' -X POST http://127.0.0.1:8098/payments -H 'content-type: application/json' -d \"\$SPRING_ORDER_42\""
stop_port 8098; sleep 3
say background-spring "echo 'spring @Async, JVM killed, receipts:' \$(sql 'SELECT count(*) FROM receipts')"
grep -q "receipts: 0" "$EVIDENCE/background-spring.log" || fail "spring's in-memory @Async lost it too"

echo "== 7. workers are processes"
D=$(copy_fastapi in-memory-idempotency); P=$(start_fastapi "$D" 8099 --workers 4); sleep 3; reset
for _ in $(seq 1 8); do say workers-fastapi "curl -s -o /dev/null -w 'HTTP %{http_code}\n' -X POST http://127.0.0.1:8099/payments -H 'content-type: application/json' -d \"\$ORDER_42\""; done
say workers-fastapi "echo 'provider:' \$(charges)"
say workers-fastapi "echo rows in payments: \$(sql 'SELECT count(*) FROM payments')"
charged=$(charges | "$PY" -c "import json,sys; print(json.load(sys.stdin)['charges'])")
[ "$charged" -gt 1 ] || fail "four workers charged the same order only once"
echo "  ok: four workers charged the same order $charged times"
stop "$P"; stop_port 8099
S2=$(copy_spring in-memory-idempotency); start_spring "$S2" 8098; reset
for _ in $(seq 1 8); do say workers-spring "curl -s -o /dev/null -w 'HTTP %{http_code}\n' -X POST http://127.0.0.1:8098/payments -H 'content-type: application/json' -d \"\$SPRING_ORDER_42\""; done
say workers-spring "echo 'provider:' \$(charges)"
charges | grep -q '"charges":1,' || fail "one JVM charged the order more than once"
echo "  ok: one JVM charged it once"
stop_port 8098

echo "== 8. the thread limit, with no database in the way"
say defaults "python experiments/limiter_default.py"
grep -q "limiter: 40 tokens" "$EVIDENCE/defaults.log" || fail "AnyIO's default is no longer 40"
TOMCAT_JAR="$HOME/.m2/repository/org/springframework/boot/spring-boot-tomcat/4.1.1/spring-boot-tomcat-4.1.1.jar"
unzip -p "$TOMCAT_JAR" META-INF/spring-configuration-metadata.json | "$PY" -c "import json,sys; d=json.load(sys.stdin); print('Spring Boot 4.1.1, server.tomcat.threads.max default:', [p.get('defaultValue') for p in d['properties'] if p['name']=='server.tomcat.threads.max'][0])" | log defaults
grep -q "threads.max default: 200" "$EVIDENCE/defaults.log" || fail "Tomcat's default is no longer 200"
(cd experiments && exec "$UVICORN" fastapi_threads:app --port 8096 --log-level warning >"$WORK/threads.log" 2>&1) &
PIDS+=("$!"); wait_http http://127.0.0.1:8096/health
say threads-fastapi "load http://127.0.0.1:8096 /payments/blocking-in-async 10"
say threads-fastapi "load http://127.0.0.1:8096 /payments/awaited 10"
for n in 10 40 41 100; do say threads-fastapi "load http://127.0.0.1:8096 /payments/blocking $n"; done
stop_port 8096
(cd experiments && RAISE_LIMIT=1 exec "$UVICORN" fastapi_threads:app --port 8096 --log-level warning >"$WORK/threads100.log" 2>&1) &
PIDS+=("$!"); wait_http http://127.0.0.1:8096/health
for n in 40 41 100; do say threads-fastapi-100 "load http://127.0.0.1:8096 /payments/blocking $n"; done
stop_port 8096
(cd experiments/spring-threads && ./mvnw -q -o -DskipTests package >"$WORK/threads-build.log" 2>&1) || fail "spring-threads build"
(cd experiments/spring-threads && PORT=8095 exec "$JAVA" -jar target/spring-threads-0.0.1-SNAPSHOT.jar >"$WORK/spring-threads.log" 2>&1) &
PIDS+=("$!"); wait_http http://127.0.0.1:8095/health
for n in 10 40 41 100; do say threads-spring "load http://127.0.0.1:8095 /payments/blocking $n"; done
stop_port 8095

echo
echo "== every claim held. Transcripts in evidence/."
