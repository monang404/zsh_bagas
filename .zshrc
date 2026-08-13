# ============================================================
#  .zshrc — loader tipis. Semua config sebenarnya ada di
#  ~/.zsh_bagas/ (lihat ~/.zsh_bagas/README.md). Jangan taruh
#  logic baru di sini — tambahin file baru di ~/.zsh_bagas/
#  dengan prefix angka yang sesuai.
# ============================================================

# ─── Profiling (opsional, toggle: ZPROF=1 zsh) ───────────────
[[ -n "$ZPROF" ]] && zmodload zsh/zprof

export ZSH_BAGAS="$HOME/.zsh_bagas"

# ─── Source semua modul, urut sesuai nama folder/file ───────
# (00-core/secrets-guard.zsh ke-source di sini juga, paling awal
# karena "00-core" alfabetis paling duluan — lihat README.md kalau
# mau tau kenapa file secrets aslinya TIDAK ikut di folder ini)
# "on" = eksplisit sort by name ascending, jangan andalkan urutan
# implisit glob (bisa beda antar versi/opsi zsh) — urutan 00-/10-/
# 20-/... ini krusial karena file belakangan gantung ke variabel/
# fungsi yang didefinisikan file awalan angka lebih kecil.
for _zsh_bagas_file in "$ZSH_BAGAS"/**/*.zsh(N.on); do
    source "$_zsh_bagas_file"
done
unset _zsh_bagas_file

# ─── Profiling output ────────────────────────────────────────
[[ -n "$ZPROF" ]] && zprof
