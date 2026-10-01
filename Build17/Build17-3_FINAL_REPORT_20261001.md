# Build17-3 — Pilot Corpus 200局面選定・Concept実地検証 FINAL REPORT

基準日: 2026-10-01  
Repository: inari-1234/shogi-ai-coach  
Branch: candidate/build17-3-pilot-corpus  
Build16 authority: 2ee66f25aba603621565ed8475649a5f70cdb5a4

## 判定

**BUILD17-3 PASS — SAFE PRUNING / FREEZE CANDIDATE**

このPASSは、新Intentを追加してよいという意味ではない。むしろPilotの結果、Build17-2で残した多くのConceptをproduction自動判定から外した。

## Corpus

- 総局面数: 200
- A〜G: 36 / 28 / 32 / 30 / 20 / 30 / 24
- 四間飛車または四間飛車原理検証subset: 61
- 独自教育局面: 36
- Build16公式compact precedent由来: 164
- duplicate position+move: 0
- Concept exposure minima: ALL PASS

## Source / rights

公式compact precedentの元データは第2回マイナビニュース杯電竜戦ハードウェア統一戦250局。compact recordには直前手履歴を捏造せず、previousMove=nullのまま使用した。
因果検証は独自教育局面のみで補完した。市販棋書本文・問題図・付属KIFの大量コピーは0。

## Locked Regression

position startpos moves 7g7f 8c8d 2g2f 8d8e  
move 8h7g  
expected intent rook_pawn_response  
expected confidence HIGH

**PASS**

piece_mobility / opponent_plan_response等は補助・adversarial扱いで、primary Intentを上書きしない。

## Build16 conflict audit

- Build16 code changed: NO
- MoveIntent enum changed: NO
- main changed: NO
- branch is based directly on frozen Build16 SHA
- Build17-3差分はBuild17/のデータ・検証成果物のみ

**Conflict: NONE**

## Status after Pilot

### ACTIVE_CANDIDATEを維持

- piece_mobility
- escape_route_control

### INTENT_CANDIDATEを維持

- **なし**

prophylaxis / waiting_move はEXPLANATION_ONLYへ降格。

### SUBINTENT_CANDIDATEを維持

- attack_attacker

ただし新MoveIntent enumにはしない。capture_threat_response / defense / piece_defense配下のmetadataとして扱う。

### EXPLANATION_ONLY

既存:
- shift_battlefront
- parallel_flexibility
- respond_to_rapid_attack
- invite_then_counter

Build17-3で降格:
- preserve_key_piece
- deny_ideal_formation
- create_battlefront
- tempo_management
- speed_over_material
- trade_to_transform
- prophylaxis
- multi_threat
- waiting_move
- sabai
- maintain_counterattack_potential

### MERGE_WITH_EXISTING

- rook_activation
- castle_completion
- avoid_premature_attack
- formation_order

### REJECTED

- bishop_exchange_decision
- rook_exchange_decision
- opponent_plan_response

## False Positive

最も高リスク: **waiting_move**

理由:
- quiet moveを手待ちと美化しやすい
- tenuki / developmentとの境界にcounterfactualが必要
- positive 5 に対し confirmed positive 0

次点:
- prophylaxis: confirmed 0
- sabai: confirmed 0

## Geometry audit

公式164局面を独立に再計算した。

- piece_mobility confirmed positive: 6
- escape_route_control confirmed positive: 6
- attack_attacker confirmed positive: 6（causal educational fixture）

geometryはIntent Authorityには使わない。

## Engine / counterfactual

Pilot中にengine/counterfactualを必要とした high-risk Conceptは production候補として通していない。

REQUIRED_NOT_AVAILABLEとなったConcept:
- prophylaxis
- waiting_move
- sabai
- speed_over_material
- multi_threat
- tempo_management
- trade_to_transform 等

これらは「未検証のまま維持」ではなく **EXPLANATION_ONLYへ降格** したため、Build17-4の自動実装対象にはしない。

## Concept Dictionary v0.1修正

主要変更:
- prophylaxis INTENT_CANDIDATE → EXPLANATION_ONLY
- waiting_move INTENT_CANDIDATE → EXPLANATION_ONLY
- deny_ideal_formation SUBINTENT_CANDIDATE → EXPLANATION_ONLY
- create_battlefront SUBINTENT_CANDIDATE → EXPLANATION_ONLY
- preserve_key_piece ACTIVE_CANDIDATE → EXPLANATION_ONLY
- tempo_management ACTIVE_CANDIDATE → EXPLANATION_ONLY
- speed_over_material ACTIVE_CANDIDATE → EXPLANATION_ONLY
- trade_to_transform ACTIVE_CANDIDATE → EXPLANATION_ONLY
- multi_threat ACTIVE_CANDIDATE → EXPLANATION_ONLY
- sabai ACTIVE_CANDIDATE → EXPLANATION_ONLY
- maintain_counterattack_potential ACTIVE_CANDIDATE → EXPLANATION_ONLY

## Build17-4へ渡す実装候補

1. piece_mobility_effect
   - Effect/HumanConcept
   - measured mobility delta
   - primary Intentを変更しない

2. escape_route_control_effect
   - Effect/HumanConcept
   - opponent safe king-move delta
   - mating/threatmate/control Intentを変更しない

3. attack_attacker_subintent
   - SubIntent metadata
   - concrete attacker + concrete threatがある場合だけ
   - parent Build16 Intent維持

**MoveIntent enum change: NONE**

## 未解決事項

- waiting_moveを将来再検討する場合は、counterfactualで「先に決める不利益」を確認できる専用Corpusが必要。
- prophylaxis再検討には、具体的opponent planと現手によるplan成立率低下を比較するCorpusが必要。
- sabai再検討には、交換/進出前後のmajor-piece effective mobilityと攻撃継続を含むmulti-ply dataが必要。
- speed_over_material / multi_threat はstable engine response setを含む別Pilotが必要。

これらはBuild17-4のblocking issueではない。Build17-4では上記3候補だけを扱う。

## Build17-4

**PROCEED: YES — LIMITED SAFE SCOPE**

ただし、
- 新Intent追加なし
- MoveIntent enum変更なし
- EXPLANATION_ONLY群のproduction自動判定なし
- Build16 Locked Regressionを最優先維持
