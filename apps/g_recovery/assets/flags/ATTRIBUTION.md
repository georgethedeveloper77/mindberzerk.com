# Flags

Source: https://github.com/hampusborgos/country-flags

The upstream project states that flags are not under copyright protection and
are in the public domain. The SVG originals were rasterised to 72 by 48 lossless
WebP, which is 3x for the 24 by 16 the picker draws.

The file name is a LANGUAGE code, not a country code. The country standing in
for each language is a product decision recorded in g_strings.dart, and
replacing one is a matter of overwriting a single file:

  en gb    ha ng    pl pl    th th
  am et    hi in    pt br    tr tr
  ar sa    id id    ru ru    ur pk
  bn bd    it it    es es    vi vn
  zh cn    ko kr    sw ke
  nl nl    fil ph   ta in
  fr fr    de de    te in
