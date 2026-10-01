# Build17-3 False Positive Analysis v0.1

基準日: 2026-10-01

## 結論

Build17-3では「説明できそう」より「誤説明しない」を優先した。positive exposure数を満たしても、独立確認できないpositiveは production候補として数えない。

最もFalse Positive Riskが高かったのは **waiting_move**。次点は **prophylaxis / sabai**。

- waiting_move: positive 5, confirmed 0, negative 5, adversarial 5
- prophylaxis: positive 6, confirmed 0, negative 5, adversarial 5
- sabai: positive 7, confirmed 0, negative 4, adversarial 4

これらは全て自動production labelから外し、EXPLANATION_ONLYへ降格する。

## 主要な誤検出パターン

1. **waiting_move ← quiet move**
   - 静かな端歩・低コミット手を「手待ち」と呼びやすい。
   - tenuki、development、formation timingとの境界にcounterfactualが必要。
   - Pilotではconfirmed positive 0。

2. **prophylaxis ← quiet defense / preparation**
   - 相手planを特定しただけでは不足し、現手がそのplanの成立性を実際に下げる必要がある。
   - 当初positive候補は「事前準備」であって「plan suppression」を証明できず、全件provisionalへ戻した。
   - Pilotではconfirmed positive 0。

3. **sabai ← exchange / major-piece move**
   - 四間飛車・大駒交換・可動域増加だけではさばきにならない。
   - post-exchange activation continuityまで必要。
   - 61局面の四間飛車系subsetでもconfirmed positive 0。

4. **speed_over_material ← forcing-looking move**
   - 駒損と速度の比較にはstable engine / counterfactualが必要。
   - confirmed positive 0。

5. **multi_threat ← multiple attacked pieces**
   - geometryで複数対象を攻撃していても、一つの応手で同時解消される可能性がある。
   - 5 positive candidateは残したがconfirmed 0。

## geometry監査で救済できたConcept

- piece_mobility: confirmed positive 6
- escape_route_control: confirmed positive 6

この2つは目的推定ではなく、観測可能なEffect / HumanConceptとして扱うことでFalse Positiveを制御できる。

## causal fixtureで安定したConcept

- attack_attacker: confirmed positive 6
- parent Build16 Intentは capture_threat_response / defense / piece_defense のまま。
- attack_attackerはSubIntent metadataとしてのみ扱う。

## 全Concept exposure

| Concept | Positive | Negative | Adversarial | Confirmed Positive |
| --- | ---: | ---: | ---: | ---: |
| piece_mobility | 6 | 3 | 17 | 6 |
| preserve_key_piece | 11 | 3 | 3 | 0 |
| deny_ideal_formation | 6 | 4 | 4 | 0 |
| create_battlefront | 5 | 3 | 3 | 0 |
| shift_battlefront | 3 | 3 | 4 | 0 |
| attack_attacker | 6 | 3 | 3 | 6 |
| tempo_management | 9 | 4 | 4 | 0 |
| speed_over_material | 6 | 3 | 4 | 0 |
| trade_to_transform | 8 | 3 | 3 | 0 |
| prophylaxis | 6 | 5 | 5 | 0 |
| escape_route_control | 6 | 3 | 9 | 6 |
| multi_threat | 5 | 3 | 9 | 0 |
| waiting_move | 5 | 5 | 5 | 0 |
| parallel_flexibility | 5 | 4 | 5 | 0 |
| sabai | 7 | 4 | 4 | 0 |
| rook_activation | 0 | 2 | 2 | 0 |
| bishop_exchange_decision | 0 | 1 | 2 | 0 |
| rook_exchange_decision | 0 | 1 | 2 | 0 |
| castle_completion | 0 | 2 | 2 | 0 |
| respond_to_rapid_attack | 6 | 3 | 4 | 6 |
| maintain_counterattack_potential | 11 | 4 | 4 | 0 |
| avoid_premature_attack | 0 | 3 | 3 | 0 |
| invite_then_counter | 6 | 4 | 5 | 0 |
| formation_order | 0 | 3 | 6 | 0 |
| opponent_plan_response | 0 | 2 | 12 | 0 |
