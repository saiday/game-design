# Decisions: W2 gaps the design leaves open

Small numbers/rules the corpus doesn't pin, decided during W2 implementation (all are v1
knobs; the interesting ones go into the W6 balance report):

| Gap | Decision | Where |
|---|---|---|
| 節點 known:unknown ratio (design gives only "1–3 nodes, unknown=60/40") | 50/50 | map_nodes.gd |
| 隱藏戰 share among unknown battles | 20% | map_nodes.gd |
| 略過節點 cost (付錢略過, no number) | 10×時代係數 (same as battle retreat) | map_nodes.gd |
| 建立國教 +30 decay schedule (隨時代衰退) | −10 per era transition (gone in 3 eras) | happiness.gd |
| Base population cap with zero livelihood investment | 20 | data/buildings.gd |
| 升級的階差額 | 基準錢 × tier difference (tiers advance one at a time → base × 1) | operations.gd |
| 國寶 sale price / culture on acquisition (no numbers) | 30×係數 / +5 culture | economy.gd, data/opportunities.gd |
| 國寶 base opportunity weight | 0 (only reachable via 天文線 +10 / 登月 +20) | data/opportunities.gd |
| Starting deck (deck ≥5 implied from generation 1, none named) | 5× 步兵團 | cards.gd |
| Build/unlock/skip costs and money floor | ALL may push treasury negative — debt is the brake, no wall | operations.gd etc. |
| Stat scaling | Evolving cards (units/forts) scale attack/hp/軍費 by their tier's era coefficient; skills stay flat (era-neutral by design) | cards.gd |

**Design observation to surface in the W6 report:** 隱藏災難 endure (−25×係數) vs mitigate
(pay 15×係數, take −10×係數) is a money wash — identical total. As written, mitigation has no
mechanical upside. Either intended as a psychological choice or a knob to revisit.
