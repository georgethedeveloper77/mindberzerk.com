#!/bin/bash
# Run from the monorepo root. Confirms the drop landed and is internally consistent.
K=apps/g_launcher/android/app/src/main/kotlin/com/mindhunter/g_launcher/icons
T=apps/g_launcher/tools/icons
A=admin/src

pass=0; fail=0
ck() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL  $1"; fi; }

echo "── files present ──"
for f in $T/RUNBOOK.md $T/build-vector-pack.mjs $T/inspect-iconset.mjs $T/svg-to-path.mjs \
         $T/pack-shape.test.mjs $K/IconContrast.kt $K/BrandIconResolver.kt \
         $A/lib/g-launcher/distro-recipes.ts $A/app/components/distro-strip.tsx; do
  ck "$f exists" "[ -f $f ]"
done

echo "── Kotlin wired together ──"
ck "resolver declares parsePaths"   "grep -q 'fun parsePaths' $K/BrandIconResolver.kt"
ck "cache calls parsePaths"         "grep -q 'brands.parsePaths' $K/IconCache.kt"
ck "old parsePath call gone"        "! grep -q 'brands.parsePath(' $K/IconCache.kt"
ck "resolver streams with JsonReader" "grep -q 'JsonReader' $K/BrandIconResolver.kt"
ck "resolver filters to installed"  "grep -q 'getInstalledApplications' $K/BrandIconResolver.kt"
ck "renderer takes a path list"     "grep -q 'paths: List<Path>' $K/IconRenderer.kt"
ck "renderer strokes"               "grep -q 'Paint.Style.STROKE' $K/IconRenderer.kt"
ck "round caps set"                 "grep -q 'Paint.Cap.ROUND' $K/IconRenderer.kt"
ck "contrast fix present"           "grep -q 'legibilityPlan' $K/IconRenderer.kt"

echo "── scripts parse ──"
for f in $T/*.mjs; do ck "$(basename $f)" "node --check $f 2>/dev/null"; done

echo "── nothing nested ──"
ck "no mindberzerk/mindberzerk" "[ ! -d mindberzerk ]"

echo
echo "  $pass passed, $fail failed"
[ $fail -eq 0 ]
