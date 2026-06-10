You are a senior mobile UI/UX reviewer scoring an iOS app (GO エクササイズ, a Japanese habit-tracking app for daily exercise). A redesign replaced cat "decoration items" with a streak-based metallic **rank/title system**. Please VIEW these PNG screenshots in this folder and score them. The files are in the current directory:

- `harness_light.png` — a developer test harness showing ALL components at once: (top) the 11 metallic title badges "RankBadge" from rank1 みならいネコ (bronze) → rank11 ぬしネコ (rainbow); (middle) "background swatches" of the achievement backdrop at streak 0/7/30/100/365/500 each with its title badge; (bottom) a sample minor-celebration toast and friend-ring colors.
- `home_rank10_light.png` — the real Home screen at a 365-day streak (rank 10 レジェンドネコ / platinum). The streak chip "🔥365日連続" has the title badge directly beneath it; a green "今日は達成済み" chip is top-right.
- `friends_light.png` — the Friends list. Each friend avatar has a colored metallic ring indicating their rank (from their current streak); streak number shown below each.

Design intent (the bar to judge against):
- **A 背景 (background)**: should get progressively richer/more premium as streak rank rises (bronze→silver→gold→platinum→rainbow), but stay TASTEFUL — explicitly NOT garish (a previous version had "too much yellow" at 365/500 and was rejected). Must not bury the cat character. Pinnacle ranks (platinum/rainbow) should still feel clearly the most special.
- **C 称号バッジ (title badge)**: metallic capsule, must look PREMIUM not cheap/candy, with the 5 metal tiers visually distinct, text legible (black text on metal), and not wrapping.
- **B 瞬間演出 (minor celebration)**: the toast should be readable and feel like a light, non-intrusive reward.
- **F 友達 (friends)**: each friend's rank should be conveyed via the avatar ring color; titles appear in the friend detail screen.

For EACH of these items, give a score 0–3 (0=broken, 1=poor, 2=acceptable/passing, 3=excellent) and ONE concrete, specific improvement instruction (reference colors/sizes/opacity where possible):

A1. Rank identifiability — can you tell higher ranks apart at a glance? (esp. is platinum/365 clearly more premium than mid gold, or does it look washed-out/plain?)
A2. Tastefulness — refined, not garish/cheap?
A3. Cat stays the hero (home screen) — background doesn't bury it?
C1. Metallic quality — premium vs cheap/candy?
C2. Metal tier distinctness — are bronze/silver/gold/platinum/rainbow clearly different?
C3. Badge legibility & layout — text readable, single-line, well placed under the streak chip?
B1. Toast readability & restraint.
F1. Friend ring rank conveyance — can you distinguish friend ranks by ring color?

End with: (1) a TOTAL/24, (2) the TOP 3 highest-priority fixes ranked, and (3) a one-line PASS/FAIL verdict (PASS = every item ≥2).

Be blunt and specific — this is a quality gate, not encouragement. Output plain text.